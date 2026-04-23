file_path = "/app/app/model/data_source.py"
with open(file_path, "r") as f:
    content = f.read()

old_func = """            trino.client._original_request_delete = trino.client.TrinoRequest._delete
            def _patched_delete(self, url, *args, **kwargs):
                url = url.replace("https://trino:8080", "http://trino:8080")
                return trino.client._original_request_delete(self, url, *args, **kwargs)
            trino.client.TrinoRequest._delete = _patched_delete"""

new_func = """            trino.client._original_request_delete = trino.client.TrinoRequest.delete
            def _patched_delete(self, url, *args, **kwargs):
                url = url.replace("https://trino:8080", "http://trino:8080")
                return trino.client._original_request_delete(self, url, *args, **kwargs)
            trino.client.TrinoRequest.delete = _patched_delete"""

if old_func in content:
    content = content.replace(old_func, new_func)

old_get = """            trino.client._original_request_get = trino.client.TrinoRequest._get
            def _patched_get(self, url, *args, **kwargs):
                url = url.replace("https://trino:8080", "http://trino:8080")
                return trino.client._original_request_get(self, url, *args, **kwargs)
            trino.client.TrinoRequest._get = _patched_get"""

new_get = """            trino.client._original_request_get = trino.client.TrinoRequest.get
            def _patched_get(self, url, *args, **kwargs):
                url = url.replace("https://trino:8080", "http://trino:8080")
                return trino.client._original_request_get(self, url, *args, **kwargs)
            trino.client.TrinoRequest.get = _patched_get"""

if old_get in content:
    content = content.replace(old_get, new_get)

with open(file_path, "w") as f:
    f.write(content)
print("Repatched data_source.py successfully")
