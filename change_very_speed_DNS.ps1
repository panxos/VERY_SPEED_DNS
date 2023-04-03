# Lista de servidores DNS para comparar
$dnsList = @{
    "Google" = @("8.8.8.8", "8.8.4.4")
    "Verisign" = @("64.6.64.6", "64.6.65.6")
    "Quad9" = @("9.9.9.9")
    "Cloudflare" = @("1.1.1.1", "1.0.0.1")
    "Comodo Secure DNS" = @("8.26.56.26", "8.20.247.20")
    "CyberGhost" = @("38.132.106.139", "194.187.251.67")
    "UncensoredDNS" = @("91.239.100.100")
    "CleanBrowsing" = @("185.228.168.168", "185.228.168.169")
}

# Obtener todas las interfaces de red
$interfaces = Get-NetAdapter | Where-Object {$_.InterfaceDescription -notlike "*VMware*" -and $_.__InterfaceDescription -notlike "*TUN*"}

# Obtener los servidores DNS públicos más rápidos
$dnsResults = foreach ($company in $dnsList.Keys) {
    foreach ($dns in $dnsList[$company]) {
        Write-Host "Probando servidor DNS de ${company}: $dns"
        $result = Test-NetConnection -ComputerName $dns
        if ($result.PingReplyDetails.RoundtripTime -gt 0) {
            if ($result.PingReplyDetails.RoundtripTime -gt 70) {
                Write-Host "Velocidad: $($result.PingReplyDetails.RoundtripTime) ms" -ForegroundColor Red
            } elseif ($result.PingReplyDetails.RoundtripTime -le 30) {
                Write-Host "Velocidad: $($result.PingReplyDetails.RoundtripTime) ms" -ForegroundColor Green
            } else {
                Write-Host "Velocidad: $($result.PingReplyDetails.RoundtripTime) ms" -ForegroundColor Yellow
            }
            [PSCustomObject]@{
                Company = $company
                Dns = $dns
                Speed = $result.PingReplyDetails.RoundtripTime
            }
        } else {
            Write-Host "Servidor no disponible"
        }
    }
}
$fastestCompany = $dnsResults | Group-Object Company | Sort-Object @{Expression={($_.Group | Measure-Object Speed -Average).Average}} | Select-Object -First 1
$fastestDns = $fastestCompany.Group | Sort-Object Speed | Select-Object -First 2

# Mostrar los servidores DNS más rápidos
Write-Host "`nLos servidores DNS más rápidos son de la empresa: $($fastestCompany.Name)"
Write-Host "Servidor DNS primario: $($fastestDns[0].Dns)"
Write-Host "Servidor DNS secundario: $($fastestDns[1].Dns)"

# Preguntar al usuario si desea cambiar el servidor DNS
$changeDns = Read-Host -Prompt '¿Desea cambiar el servidor DNS en todas las interfaces? (s/n)'

if ($changeDns -eq 's') {
    # Cambiar el servidor DNS en las interfaces de red
    foreach ($interface in $interfaces) {
        Set-DnsClientServerAddress -InterfaceIndex $interface.ifIndex -ServerAddresses $fastestDns.Dns
        Write-Host "Se cambió el servidor DNS en la interfaz: $($interface.Name)"
    }
}
