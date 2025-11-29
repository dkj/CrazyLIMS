"""
Helper utilities for running the generated client inside Pyodide/JupyterLite.

This module patches httpx to run over the browser fetch API via ``pyodide-http``
and builds an AuthenticatedClient using auth context passed from the host page.
"""
from __future__ import annotations

from typing import Optional, Dict, Any
import httpx

import js  # type: ignore
import pyodide_http

from .client import AuthenticatedClient

_PATCHED = False
DEFAULT_CLIENT_APP = "crazylims-eln-pyodide"


def _patch_httpx() -> None:
    global _PATCHED
    if _PATCHED:
        return
    pyodide_http.patch_all()
    _PATCHED = True


def _pyfetch_transport() -> Optional[httpx.MockTransport]:
    """
    Provide an httpx transport that bridges to the browser fetch API via pyodide.http.pyfetch.
    Returns None when running outside Pyodide.
    """
    try:
        from pyodide.http import pyfetch
    except Exception:
        return None

    async def handler(request: httpx.Request) -> httpx.Response:
        init: Dict[str, Any] = {"method": request.method, "headers": dict(request.headers)}
        if request.content:
            init["body"] = request.content
        response = await pyfetch(str(request.url), **init)
        body = await response.bytes()
        headers = {key: value for key, value in response.headers.items()}
        return httpx.Response(
            status_code=response.status,
            headers=headers,
            content=body,
            request=request,
        )

    return httpx.MockTransport(handler)


def _get_storage_value(key: str) -> Optional[str]:
    def _read(window: object, name: str) -> Optional[str]:
        try:
            storage = getattr(window, name)
            value = storage.getItem(key)
            if value not in (None, js.undefined):
                text = str(value)
                if text:
                    return text
        except Exception:
            return None
        return None

    windows = []
    try:
        windows.append(js.window)
    except Exception:
        pass
    try:
        parent = getattr(js, "parent", None)
        if parent not in (None, js.undefined):
            windows.append(parent)
    except Exception:
        pass

    for candidate in windows:
        for container in ("sessionStorage", "localStorage"):
            found = _read(candidate, container)
            if found:
                return found
    return None


def resolve_api_base(default: str = "/api") -> str:
    """Best-effort lookup of the PostgREST base URL from the host page."""
    origin_candidates = []
    for attr in ("window", "parent"):
        try:
            win = getattr(js, attr)
            origin_candidates.append(str(win.location.origin))
        except Exception:
            continue
    origin = origin_candidates[0] if origin_candidates else ""
    try:
        resolved = getattr(js.globalThis, "_crazylimsApiResolved", None)  # type: ignore[attr-defined]
        if resolved not in (None, js.undefined):
            candidate_str = str(resolved)
            if candidate_str:
                return candidate_str
    except Exception:
        pass
    try:
        candidate = getattr(js, "elnApiBase", None)
        if candidate not in (None, js.undefined) and str(candidate):
            candidate_str = str(candidate)
            if candidate_str.startswith("/"):
                return f"{origin}{candidate_str}"
            return candidate_str
    except Exception:
        pass
    try:
        alt_candidate = getattr(js, "__crazylimsApiBase", None)
        if alt_candidate not in (None, js.undefined) and str(alt_candidate):
            candidate_str = str(alt_candidate)
            if candidate_str.startswith("/"):
                return f"{origin}{candidate_str}"
            return candidate_str
    except Exception:
        pass
    try:
        worker_base = getattr(js.globalThis, "_crazylimsApiBase", None)  # type: ignore[attr-defined]
        if worker_base not in (None, js.undefined):
            candidate_str = str(worker_base)
            if candidate_str.startswith("/"):
                return f"{origin}{candidate_str}"
            return candidate_str
    except Exception:
        pass
    try:
        parent_base = getattr(getattr(js, "parent", None), "elnApiBase", None)
        if parent_base not in (None, js.undefined):
            candidate_str = str(parent_base)
            if candidate_str.startswith("/"):
                return f"{origin}{candidate_str}"
            return candidate_str
    except Exception:
        pass
    try:
        parent_alt_base = getattr(getattr(js, "parent", None), "__crazylimsApiBase", None)
        if parent_alt_base not in (None, js.undefined):
            candidate_str = str(parent_alt_base)
            if candidate_str.startswith("/"):
                return f"{origin}{candidate_str}"
            return candidate_str
    except Exception:
        pass
    fallback = _get_storage_value("elnApiBase")
    base = fallback or default
    if base.startswith("/") and origin:
        return f"{origin}{base}"
    return base


def resolve_auth_token() -> Optional[str]:
    """Best-effort lookup of the bearer token exposed by the host page."""
    for attr in ("elnAuthToken", "__crazylimsAuthToken"):
        try:
            candidate = getattr(js, attr, None)
            if candidate not in (None, js.undefined) and str(candidate):
                return str(candidate)
        except Exception:
            pass
        try:
            parent = getattr(js, "parent", None)
            candidate_parent = getattr(parent, attr, None)
            if candidate_parent not in (None, js.undefined) and str(candidate_parent):
                return str(candidate_parent)
        except Exception:
            pass
    try:
        worker_token = getattr(js.globalThis, "_crazylimsAuthToken", None)  # type: ignore[attr-defined]
        if worker_token not in (None, js.undefined) and str(worker_token):
            return str(worker_token)
    except Exception:
        pass
    return _get_storage_value("elnAuthToken")


def build_authenticated_client(
    *,
    base_url: Optional[str] = None,
    token: Optional[str] = None,
    timeout: float = 30.0,
    client_app: str = DEFAULT_CLIENT_APP,
    prefer_header: str = "tx=commit",
    extra_headers: Optional[Dict[str, str]] = None,
    httpx_args: Optional[Dict[str, Any]] = None,
) -> AuthenticatedClient:
    """
    Construct an AuthenticatedClient ready for Pyodide/Browser use.

    - Patches httpx with pyodide-http so requests flow through window.fetch.
    - Pulls base URL and bearer token from JS globals/sessionStorage when not provided.
    - Sets a Prefer header to ensure PostgREST commits and records transaction context metadata.
    """
    _patch_httpx()
    resolved_base = base_url or resolve_api_base()
    resolved_token = token or resolve_auth_token()
    if not resolved_token:
        raise RuntimeError("No auth token available for PostgREST calls in Pyodide.")
    auth_prefix = "Bearer" if resolved_token else ""
    headers: Dict[str, str] = {
        "X-Client-App": client_app,
        "Prefer": prefer_header,
    }
    if extra_headers:
        headers.update(extra_headers)

    transport = _pyfetch_transport()
    client_kwargs: Dict[str, Any] = {**(httpx_args or {})}
    if transport and "transport" not in client_kwargs:
        client_kwargs["transport"] = transport

    return AuthenticatedClient(
        base_url=resolved_base,
        token=resolved_token or "",
        prefix=auth_prefix,
        headers=headers,
        timeout=timeout,
        follow_redirects=False,
        verify_ssl=False,
        httpx_args=client_kwargs,
    )
