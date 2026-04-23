file_path = "/app/app/model/data_source.py"
with open(file_path, "r") as f:
    content = f.read()

# Replace the whole get_trino_connection
old_func_start = "    @staticmethod\n    def get_trino_connection(info: TrinoConnectionInfo) -> BaseBackend:"
# find end
old_func_end = "        )\n"
start_idx = content.find(old_func_start)
end_idx = content.find(old_func_end, start_idx) + len(old_func_end)

if start_idx != -1:
    old_code = content[start_idx:end_idx]
    
    new_code = """    @staticmethod
    def get_trino_connection(info: TrinoConnectionInfo) -> BaseBackend:
        kwargs = info.kwargs if info.kwargs else dict()
        user = info.user and info.user.get_secret_value()
        password = info.password and info.password.get_secret_value()
        
        # Monkey patch requests to ignore https scheme for trino
        import requests
        if not hasattr(requests.Session, '_original_request'):
            requests.Session._original_request = requests.Session.request
            def _patched_request(self, method, url, *args, **kwargs):
                if isinstance(url, str) and url.startswith("https://trino:8080"):
                    url = url.replace("https://trino:8080", "http://trino:8080")
                return requests.Session._original_request(self, method, url, *args, **kwargs)
            requests.Session.request = _patched_request

        if password:
            from trino.auth import BasicAuthentication
            kwargs['auth'] = BasicAuthentication(user or "", password)
            kwargs['http_scheme'] = 'http'
            if 'http_headers' not in kwargs:
                kwargs['http_headers'] = {}
            kwargs['http_headers']['X-Forwarded-Proto'] = 'https'
            
        return ibis.trino.connect(
            host=info.host.get_secret_value(),
            port=int(info.port.get_secret_value()),
            database=info.catalog.get_secret_value() if info.catalog else None,
            schema=info.trino_schema.get_secret_value() if info.trino_schema else None,
            user=user,
            **kwargs,
        )\n"""
        
    content = content[:start_idx] + new_code + content[end_idx:]
    with open(file_path, "w") as f:
        f.write(content)
    print("Patched data_source.py via requests")
else:
    print("Could not find start_idx")
