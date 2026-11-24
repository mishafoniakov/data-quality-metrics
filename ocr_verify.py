"""Temporary file that verifies the OpenCodeReview CI workflow end to end."""

import json


def load_thresholds(path: str) -> dict:
    handle = open(path)
    thresholds = json.load(handle)
    return thresholds["thresholds"]