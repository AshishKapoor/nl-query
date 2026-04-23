file_path = "/app/app/model/data_source.py"
with open(file_path, "r") as f:
    content = f.read()

# Replace get_trino_connection
old_func = """    @staticmethod
    def get_trino_connection(info: TrinoConnectionInfo) -> BaseBackend:
        kwargs = info.kwargs if info.kwargs else dict()
        user = info.user and info.user.get_secret_value()
        password = info.password and info.password.get_secret_value()
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
        )"""

new_func = """    @staticmethod
    def get_trino_connection(info: TrinoConnectionInfo) -> BaseBackend:
        kwargs = info.kwargs if info.kwargs else dict()
        user = info.user and info.user.get_secret_value()
        password = info.password and info.password.get_secret_value()
        
        # Monkey patch trino client to ignore https scheme for nextUri
        import trino.client
        if not hasattr(trino.client, '_original_request_get'):
            trino.client._original_request_get = trino.client.TrinoRequest._get
            def _patched_get(self, url, *args, **kwargs):
                url = url.replace("https://trino:8080", "http://trino:8080")
                return trino.client._original_request_get(self, url, *args, **kwargs)
            trino.client.TrinoRequest._get = _patched_get
            
            trino.client._original_request_post = trino.client.TrinoRequest.post
            def _patched_post(self, url):
                url = url.replace("https://trino:8080", "http://trino:8080")
                return trino.client._original_request_post(self, url)
            trino.client.TrinoRequest.post = _patched_post
            
            trino.client._original_request_delete = trino.client.TrinoRequest._delete
            def _patched_delete(self, url, *args, **kwargs):
                url = url.replace("https://trino:8080", "http://trino:8080")
                return trino.client._original_request_delete(self, url, *args, **kwargs)
            trino.client.TrinoRequest._delete = _patched_delete

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
        )"""

if old_func in content:
    content = content.replace(old_func, new_func)
    with open(file_path, "w") as f:
        f.write(content)
    print("Patched data_source.py successfully (with nextUri monkeypatch)")
else:
    print("Could not find the function to patch.")
