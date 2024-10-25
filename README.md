This is a simple application i made because at work we use MacBooks, and i needed a way to proxy localhost in MacOS to a VM running Windows in VMWare Fusion. This application will create a two-way binding that allows you to access localhost servers running on MacOS in Windows. Use the config.ini file to set a source and target port, and a source and target IP, and a hostname of the MacOS (or any other) host system.

This tool is verry much a work in progress, and i will update this further and maybe add some more features. But for now it serves its purpose, and with the automatic IP resolving based on the hostname, the NetSH is updated whenever the network changes (connecting to another WiFi on the host for example).
If you like this tool, feel free to share it or fork it. If you have some ideas to improve this - please create a PR and ill merge it. 

The ini file explained:

```
[Settings]
ListenAddress=127.0.0.1          // This is the local address (Inside VM).
ListenPort=3010                  // This is the local port (Inside VM).
ConnectAddress=192.168.0.203     // This is the host address (fallback when hostname resolving fails)
ConnectPort=3010                 // This is the host port
HostName=MacBook-Pro-van-Ernst   // This is the hostname used to automatically resolve the ConnectAddress
```

You just need to start the application once (can only run once), and it will automatically change the NetSH when network changes.
