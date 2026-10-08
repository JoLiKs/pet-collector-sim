#!/usr/bin/env python3
"""Загрузка звуков в Roblox через Open Cloud Assets API (v3.1).

    ROBLOX_OPEN_CLOUD_KEY=… python3 tools/upload_audio.py assets/audio/calm_meadow.ogg "Display name" ["description"]

Ключ берётся только из окружения и уходит только заголовком x-api-key — скрипт его не печатает.
Печатает JSON: {"file":…, "assetId":…} или {"file":…, "error": <точный ответ API>}.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

API = "https://apis.roblox.com/assets/v1/"
CREATOR_USER_ID = "11770388445"


def call(method, url, key, body=None, ctype=None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)
    if ctype:
        req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        raw = e.read().decode(errors="replace")
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw[:2000]}


def upload(path, name, desc, key):
    meta = {
        "assetType": "Audio",
        "displayName": name[:50],
        "description": desc[:1000],
        "creationContext": {"creator": {"userId": CREATOR_USER_ID}},
    }
    b = uuid.uuid4().hex
    data = open(path, "rb").read()
    ctype = "audio/ogg" if path.endswith(".ogg") else "audio/mpeg"
    parts = [
        ("--%s\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n" % b).encode()
        + json.dumps(meta).encode() + b"\r\n",
        ("--%s\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n"
         % (b, os.path.basename(path), ctype)).encode() + data + b"\r\n",
        ("--%s--\r\n" % b).encode(),
    ]
    status, res = call("POST", API + "assets", key, b"".join(parts), "multipart/form-data; boundary=" + b)
    if status >= 300:
        return {"file": path, "httpStatus": status, "error": res}
    op = res.get("path") or ("operations/" + res.get("operationId", ""))
    for _ in range(40):
        if res.get("done"):
            break
        time.sleep(3)
        status, res = call("GET", API + op, key)
        if status >= 300:
            return {"file": path, "httpStatus": status, "error": res, "operation": op}
    if not res.get("done"):
        return {"file": path, "error": "operation not done after polling", "operation": op, "last": res}
    if "error" in res:
        return {"file": path, "error": res["error"], "operation": op}
    r = res.get("response") or {}
    return {"file": path, "assetId": r.get("assetId"), "moderation": r.get("moderationResult"), "operation": op}


if __name__ == "__main__":
    key = os.environ.get("ROBLOX_OPEN_CLOUD_KEY", "")
    if not key:
        print(json.dumps({"error": "ROBLOX_OPEN_CLOUD_KEY is not set"}))
        sys.exit(2)
    path, name = sys.argv[1], sys.argv[2]
    desc = sys.argv[3] if len(sys.argv) > 3 else "Pet Collector Simulator — original procedural music"
    out = upload(path, name, desc, key)
    print(json.dumps(out, ensure_ascii=False))
    sys.exit(0 if out.get("assetId") else 1)
