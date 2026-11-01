from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
import json

import aiohttp


class Tools:
    class Valves(BaseModel):
        bridge_url: str = Field("http://bridge:3000", description="Bridge server URL")
        bridge_api_key: str = Field("", description="Bridge API key")
        timeout_seconds: int = Field(15, description="Request timeout in seconds")

    class UserValves(BaseModel):
        prefer_voice_note: bool = Field(
            False, description="Apply text-to-speech to message being delivered"
        )
        phone_number: str = Field(
            "", description="Your WhatsApp number, digits only, with country code"
        )

    def __init__(self):
        self.valves = self.Valves()

    # ------------------------------------------------------------------ helpers

    def _timeout(self) -> aiohttp.ClientTimeout:
        return aiohttp.ClientTimeout(total=self.valves.timeout_seconds)

    def _headers(self) -> dict:
        return {"X-Secret": self.valves.bridge_api_key}

    @staticmethod
    def _phone(__user__: dict) -> Optional[str]:
        user_valves = (__user__ or {}).get("valves")
        number = getattr(user_valves, "phone_number", "") if user_valves else ""
        return number or None

    async def _request(
        self,
        session: aiohttp.ClientSession,
        method: str,
        path: str,
        *,
        params: Optional[dict] = None,
        payload: Optional[dict] = None,
    ) -> tuple[int, str]:
        url = f"{self.valves.bridge_url.rstrip('/')}{path}"
        async with session.request(
            method, url, params=params, json=payload, headers=self._headers()
        ) as resp:
            return resp.status, await resp.text()

    # -------------------------------------------------------------------- tools

    async def get_messages(
        self,
        before: Optional[str] = None,
        limit: int = 5,
        __user__: dict = {},
    ) -> str:
        """
        Get recent WhatsApp messages in the conversation with the current user.

        Args:
        - before: only return messages before this date, formatted DD-MM-YYYY. Defaults to now.
        - limit: maximum number of messages to return.
        """

        phone = self._phone(__user__)
        if not phone:
            return "No WhatsApp number set in this user's tool settings."

        if before:
            try:
                before_date = datetime.strptime(before, "%d-%m-%Y")
            except ValueError:
                return "Invalid `before` date, expected DD-MM-YYYY."
        else:
            before_date = datetime.now()

        params = {
            "limit": limit,
            "before": before_date.strftime("%d-%m-%Y"),
            "phone_number": phone,
        }

        try:
            async with aiohttp.ClientSession(timeout=self._timeout()) as session:
                status, body = await self._request(
                    session, "GET", "/whatsapp/recent", params=params
                )
        except aiohttp.ClientError as e:
            return f"Failed to reach bridge: {e}"
        except TimeoutError:
            return "Bridge request timed out."

        if status >= 400:
            return f"Bridge error {status}: {body}"

        return body

    async def send_message(
        self,
        message_markdown: Optional[str] = None,
        reply_id: Optional[str] = None,
        sticker_url: Optional[str] = None,
        media: Optional[list[dict]] = None,
        __user__: dict = {},
    ) -> str:
        """
        Send a WhatsApp message to the current user, with optional reply id or media/sticker attached.

        Args:
        - message_markdown: message being sent, supports basic markdown.
        - reply_id: id of the message being replied to.
        - sticker_url: url of a webp sticker to send.
        - media: list of objects like {"mime_type": "image/png", "url": "https://...", "caption": "optional"}.
        """

        phone = self._phone(__user__)
        if not phone:
            return "No WhatsApp number set in this user's tool settings."

        if not message_markdown and not media and not sticker_url:
            return "Sending a message requires at least `message_markdown`, `media` or `sticker_url`."

        payload: dict = {
            "phone_number": phone,
            "prefer_voice_note": __user__["valves"].prefer_voice_note,
        }

        if message_markdown:
            payload["message"] = message_markdown
        if reply_id:
            payload["reply_id"] = reply_id
        if sticker_url:
            payload["sticker"] = {"url": sticker_url, "type": "url"}
        if media:
            try:
                payload["media"] = [
                    {
                        "mime_type": m["mime_type"],
                        "url": m["url"],
                        "caption": m.get("caption", ""),
                    }
                    for m in media
                ]
            except (KeyError, TypeError, AttributeError):
                return "Each media entry needs `mime_type` and `url` (and optionally `caption`)."

        try:
            async with aiohttp.ClientSession(timeout=self._timeout()) as session:
                status, body = await self._request(
                    session, "POST", "/whatsapp/send-message", payload=payload
                )
        except aiohttp.ClientError as e:
            return f"Failed to reach bridge: {e}"
        except TimeoutError:
            return "Bridge request timed out."

        if status >= 400:
            return f"Bridge error {status}: {body}"

        return "Message sent."
