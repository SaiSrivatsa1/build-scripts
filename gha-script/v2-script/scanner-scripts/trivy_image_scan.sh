#!/bin/bash -e

image_name=$IMAGE_NAME
build_docker=$BUILD_DOCKER
DOCKER_IMAGE="sankalppersi/trivy-db:latest"
docker pull "$DOCKER_IMAGE"
if [ "$build_docker" == true ]; then

	echo "Fetching latest Trivy version..."
	TRIVY_VERSION=$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
	FILE_NAME="trivy_${TRIVY_VERSION#v}_Linux-s390x.tar.gz"
	CHECKSUM_FILE="trivy_${TRIVY_VERSION#v}_checksums.txt"

	echo "Downloading Trivy binary..."
	wget -q https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/${FILE_NAME}
	echo "Downloading checksum file..."
	wget -q https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/${CHECKSUM_FILE}
	echo "Verifying checksum..."
	CHECKSUM_LINE=$(grep "${FILE_NAME}" "${CHECKSUM_FILE}" || true)

	if [ -z "$CHECKSUM_LINE" ]; then
		echo "[ERROR] Could not find checksum entry for ${FILE_NAME}"
		exit 1
	fi

	if echo "$CHECKSUM_LINE" | sha256sum --check --status; then
		echo "[INFO] Checksum verification successful. Installing Trivy..."
		tar -xzf ${FILE_NAME}
		chmod +x trivy
		sudo mv trivy /usr/bin
		echo "Executing trivy scanner"
		sudo trivy -q fs --timeout 30m -f json "${cloned_package}" > trivy_source_vulnerabilities_results.json || true
	    echo "trivy.db not found, copying again.."
	    find / -name "trivy.db" 2>/dev/null
		find / -type d -path "*/.cache/trivy/db" 2>/dev/null
	#   sudo chmod -R 755 "/usr/local/share/.cache/trivy/db"
	    sudo docker run -d --name trivy-container "$DOCKER_IMAGE"
	    sudo docker cp trivy-container:/trivy.db /root/.cache/trivy/db/trivy.db
	    sudo docker rm -f trivy-container
		
		sudo trivy -q image --timeout 30m -f json ${image_name} > trivy_image_vulnerabilities_results.json
		sudo trivy -q image --timeout 30m -f cyclonedx ${image_name} > trivy_image_sbom_results.cyclonedx
	else
		echo "[ERROR] Checksum verification FAILED for ${FILE_NAME}"
		echo "[ERROR] Trivy will NOT be installed due to integrity verification failure."
		exit 1
	fi
fi
