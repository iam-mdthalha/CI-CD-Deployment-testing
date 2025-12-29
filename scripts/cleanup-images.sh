#!/bin/bash
# =============================================================================
# Docker Image Cleanup Script
# =============================================================================
# Usage: sudo /usr/local/bin/cleanup-images.sh [--dry-run]
# Keeps the last 3 images, removes older ones
# =============================================================================

set -e

# Configuration
KEEP_IMAGES=3
DRY_RUN=false
IMAGE_PATTERN="ecommerce-frontend"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
if [ "$1" == "--dry-run" ]; then
    DRY_RUN=true
    echo -e "${YELLOW}[DRY RUN] No images will be deleted${NC}"
    echo ""
fi

echo "═══════════════════════════════════════════════════════════════"
echo "              DOCKER IMAGE CLEANUP"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Keep latest:  $KEEP_IMAGES images"
echo "  Pattern:      $IMAGE_PATTERN"
echo ""

# Get all images matching pattern, sorted by creation date
echo "Current images:"
echo ""
docker images --format "{{.Repository}}:{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}" | grep "$IMAGE_PATTERN" | head -20 || echo "  No matching images found"
echo ""

# Get image IDs to delete (skip first N)
IMAGES_TO_DELETE=$(docker images --format "{{.ID}}\t{{.Repository}}:{{.Tag}}" | grep "$IMAGE_PATTERN" | tail -n +$((KEEP_IMAGES + 1)) | awk '{print $1}')

if [ -z "$IMAGES_TO_DELETE" ]; then
    echo -e "${GREEN}✅ No images to clean up${NC}"
    echo "   Keeping $KEEP_IMAGES most recent images"
    exit 0
fi

# Count images to delete
DELETE_COUNT=$(echo "$IMAGES_TO_DELETE" | wc -l)
echo "Images to delete: $DELETE_COUNT"
echo ""

# Delete images
for IMAGE_ID in $IMAGES_TO_DELETE; do
    IMAGE_NAME=$(docker images --format "{{. Repository}}:{{. Tag}}" --filter "id=$IMAGE_ID" | head -1)
    
    if [ "$DRY_RUN" == "true" ]; then
        echo -e "${YELLOW}[DRY RUN] Would delete: ${NC} $IMAGE_NAME ($IMAGE_ID)"
    else
        echo -e "Deleting:  $IMAGE_NAME ($IMAGE_ID)"
        docker rmi "$IMAGE_ID" 2>/dev/null || echo "  Could not delete (may be in use)"
    fi
done

echo ""

# Cleanup dangling images
echo "Cleaning up dangling images..."
if [ "$DRY_RUN" == "true" ]; then
    DANGLING=$(docker images -f "dangling=true" -q | wc -l)
    echo -e "${YELLOW}[DRY RUN] Would remove $DANGLING dangling image(s)${NC}"
else
    docker image prune -f
fi

echo ""

# Show disk space saved
echo "Docker disk usage:"
docker system df

echo ""
echo -e "${GREEN}✅ Cleanup complete${NC}"
echo ""