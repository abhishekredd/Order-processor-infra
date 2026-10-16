"""Cloud Run entrypoint (Flask)."""
import logging

from flask import Flask, jsonify, request

from edp_compat.errors import ParseError

from .config import Config
from .factory import build_processor

log = logging.getLogger("compat")


def create_app(processor=None) -> Flask:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s %(message)s")
    app = Flask(__name__)
    processor = processor or build_processor(Config.from_env())

    @app.get("/healthz")
    def health():
        return {"status": "ok"}

    @app.post("/")
    def receive():
        headers = {k.lower(): v for k, v in request.headers.items()}
        try:
            summary = processor.handle(headers, request.get_json(silent=True))
        except ParseError as exc:
            # 400: request is malformed and retrying will not help.
            log.error("Unparseable request: %s", exc)
            return jsonify(error=str(exc)), 400
        except Exception as exc:  # noqa: BLE001
            # 5xx: transient (file not yet visible, Pub/Sub down...). EventArc/Pub/Sub will retry.
            log.exception("Processing failed")
            return jsonify(error=str(exc)), 500
        # 200 even if some records were dead-lettered: they are handled, not lost.
        return jsonify(summary.to_dict()), 200

    return app
