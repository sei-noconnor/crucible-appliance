function downloadCert() {
  const cert = `-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAKKkUw7wDcYtMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV...
-----END CERTIFICATE-----`;
  const blob = new Blob([cert], { type: 'application/x-pem-file' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = 'root-ca.pem';
  link.click();
}