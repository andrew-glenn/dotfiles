.PHONY: build

build:
	docker build --build-arg SANDBOX_USER_UID=$$(id -u) --build-arg SANDBOX_USER_GID=$$(id -g) -f Dockerfile.kiro -t kiro-sandbox .
