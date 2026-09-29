#!/usr/bin/env python3
"""Python JSON/JSONL oracle for a bounded C06 value and file-stream slice."""

import json
import sys


SOURCE = (
    '{"big":1234567890123456789012345678901234567890,'
    '"nullable":null,'
    '"nested":{"label":"blåbær","items":[true,null,4]},'
    '"duplicate":"first","duplicate":"last"}'
)
JSON_LINES_SOURCE = (
    '{"id":1,"name":"blå"}\n'
    '{"id":2,"ok":true}\n'
    '{"id":3,"payload":null}'
)


def main():
    value = json.loads(SOURCE)
    nested = value["nested"]
    items = nested["items"]
    with open(
        "test/fixtures/script_parity/json_values/records.jsonl",
        encoding="utf-8",
    ) as source:
        file_records = [json.loads(line) for line in source]
    try:
        json.loads('{"broken": }\n')
        malformed_status = "accepted"
    except json.JSONDecodeError:
        malformed_status = "error"
    lines = [
        f"big={value['big']}",
        f"missing={'present' if 'absent' in value else 'missing'}",
        f"nullable={'null' if 'nullable' in value and value['nullable'] is None else 'other'}",
        f"label={nested['label']}",
        f"items.count={len(items)}",
        f"item.0={'true' if items[0] is True else 'false'}",
        f"item.1={'null' if items[1] is None else 'other'}",
        f"item.2={items[2]}",
        f"duplicate={value['duplicate']}",
        "json="
        + json.dumps(value, ensure_ascii=False, separators=(",", ":")),
        "jsonl="
        + "|".join(
            json.dumps(json.loads(line), ensure_ascii=False, separators=(",", ":"))
            for line in JSON_LINES_SOURCE.splitlines()
        ),
        "jsonl_file="
        + "|".join(
            json.dumps(record, ensure_ascii=False, separators=(",", ":"))
            for record in file_records
        ),
        f"jsonl_malformed={malformed_status}",
    ]
    sys.stdout.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
