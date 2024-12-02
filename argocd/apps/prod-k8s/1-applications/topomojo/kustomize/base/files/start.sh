#!/bin/sh
cp /start/*.crt /usr/local/share/ca-certificates && update-ca-certificates
cd /app && dotnet TopoMojo.Api.dll