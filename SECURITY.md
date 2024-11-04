# Security Documentation

## Network Isolation for PDF Document Layout Analysis Service

This security implementation provides network isolation for the PDF document layout analysis service to prevent any potential unauthorized data exfiltration, tracking, or malicious outbound connections that could be hidden in the PDF processing libraries or models.

### Purpose

The PDF document layout analysis service processes sensitive documents. While the service itself is needed for document analysis, we need to ensure that:
1. No document data can be leaked to external servers
2. No tracking or telemetry from the libraries/models can call home
3. No potential malware that might be hidden in processed PDFs can establish outbound connections

### Security Measures

The isolation script (`strict_isolate.sh`) implements two core security rules:

1. **Controlled Inbound Access**: Only allows incoming TCP connections to port 5060 where the service listens for document processing requests
2. **Complete Outbound Blocking**: Blocks ALL outbound connections from the container, ensuring that:
   - The service cannot send document data to external servers
   - Libraries and ML models cannot phone home or send telemetry
   - No outbound connections of any kind are possible

This creates an airgapped environment where the PDF processing service:
- Can ONLY respond to document analysis requests on port 5060
- Cannot leak any document data to external sources
- Cannot perform any form of tracking or telemetry
- Cannot establish any outbound network connections

### Usage

#### Prerequisites
- Root access on the host system
- Docker installed
- iptables installed

#### Installation

1. Save the isolation script:
```bash
curl -O strict_isolate.sh
chmod +x strict_isolate.sh
```

2. Run the script as root to isolate the PDF processing service:
```bash
sudo ./strict_isolate.sh pdf-document-layout-analysis 5060
```

#### Verification

After applying the rules, verify the isolation:

1. Test that the service accepts PDF processing requests:
```bash
curl http://localhost:5060/analyze -F "file=@document.pdf"
```

2. Verify that NO data can be exfiltrated:
```bash
docker exec pdf-document-layout-analysis ping 8.8.8.8    # Should fail
docker exec pdf-document-layout-analysis curl google.com  # Should fail
```

### Implementation Details

The script implements the following iptables rules:

```bash
# Allow only incoming connections to the PDF processing port
iptables -A DOCKER-USER -p tcp --dport 5060 -d <container_ip> -j ACCEPT

# Block all outgoing traffic to prevent data exfiltration
iptables -A DOCKER-USER -s <container_ip> -j DROP
```

### Removing Security Rules

To remove the isolation rules:
```bash
# For incoming rule
iptables -D DOCKER-USER -p tcp --dport 5060 -d <container_ip> -j ACCEPT

# For outbound blocking rule
iptables -D DOCKER-USER -s <container_ip> -j DROP
```

### Security Considerations

1. **Container Restart**: The iptables rules persist across container restarts, but you should re-run the script if the container's IP address changes.

2. **Docker Network Changes**: If you modify the Docker network configuration or recreate the container, you'll need to reapply the rules.

3. **Host System Reboot**: iptables rules are not persistent across system reboots by default. Consider using a service like `iptables-persistent` or adding the script to your system's startup sequence.

4. **Monitoring**: Monitor your container logs for any suspicious connection attempts that could indicate:
   - Attempts to exfiltrate document data
   - Libraries trying to phone home
   - Malicious code attempting network access

### Troubleshooting

If the PDF processing service isn't working as expected after applying these rules:

1. Verify the container's IP address hasn't changed:
```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' pdf-document-layout-analysis
```

2. Check current iptables rules:
```bash
sudo iptables -L DOCKER-USER -v -n
```

3. Check container logs for blocked network attempts:
```bash
docker logs pdf-document-layout-analysis
```

### Contributing

When contributing to this security implementation:
- Do not add exceptions for outbound traffic
- Do not add "convenience" features that might compromise the isolation
- Document any changes thoroughly
- Include verification steps for new features

### Support

For security-related issues or questions:
1. Open an issue in the repository
2. Provide detailed information about your setup
3. Include the output of `iptables -L DOCKER-USER -v -n`
4. Do not include any sensitive document data in bug reports
