import os
import time
from typing import List, Tuple


ANNOTATIONS_PATH = os.getenv("ANNOTATIONS_PATH")


def get_pod_annotations() -> List[str]:
    def parse_annotation(annotation: str) -> Tuple[str, str]:
        k, v = annotation.split("=")
        return k, v.strip()

    with open(ANNOTATIONS_PATH, "r") as file:
        return [parse_annotation(line) for line in file]


if __name__ == "__main__":
    while True:
        time.sleep(5)
        print(get_pod_annotations())
