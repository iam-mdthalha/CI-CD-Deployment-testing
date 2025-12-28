echo "=========================================="
echo "       EC2 SETUP VERIFICATION            "
echo "=========================================="
echo ""

# Check Docker
echo "1. Docker Version:"
docker --version

echo ""
echo "2. Docker Running:"
sudo systemctl status docker | grep "Active:"

echo ""
echo "3. Docker Permission (no sudo):"
docker ps > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"

echo ""
echo "4. Deployment Directory:"
ls -la /opt/ecommerce/

echo ""
echo "5. Scripts:"
ls -la /opt/ecommerce/scripts/

echo ""
echo "6.  Firewall Status:"
sudo ufw status

echo ""
echo "=========================================="
echo "       VERIFICATION COMPLETE             "
echo "=========================================="