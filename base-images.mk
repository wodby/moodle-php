# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := wodby/php
BASE_IMAGE_VERSION_SUFFIX :=

BASE_IMAGE_DIGEST_8.4 := sha256:dab3e53c83a5297fe79fca14f06633cefc67f5752893e88abd044d902ca96a23
BASE_IMAGE_DIGEST_8.4-r14 := sha256:2e050870914947b2c711526306969f5c310d2c4e1c7a583c08a95e51ccfab74d

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
