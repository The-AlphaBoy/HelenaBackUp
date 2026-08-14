"""Groq provider profile — copy to $HERMES_HOME/plugins/model-providers/groq/__init__.py

Groq serves OpenAI-compatible endpoints at https://api.groq.com/openai/v1.
Auth is a plain API key via GROQ_API_KEY. No request-shape quirks — the
standard chat_completions path works as-is. See SKILL.md for the matching
plugin.yaml manifest.
"""

from __future__ import annotations

from providers import register_provider
from providers.base import ProviderProfile

groq = ProviderProfile(
    name="groq",
    aliases=("groq",),
    env_vars=("GROQ_API_KEY",),
    display_name="Groq",
    description="Groq (LPU-powered fast inference, OpenAI-compatible)",
    signup_url="https://console.groq.com/keys",
    fallback_models=(
        "llama-3.3-70b-versatile",
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b",
        "qwen/qwen3.6-27b",
        "llama-3.1-8b-instant",
    ),
    base_url="https://api.groq.com/openai/v1",
    default_aux_model="llama-3.1-8b-instant",
)

register_provider(groq)
