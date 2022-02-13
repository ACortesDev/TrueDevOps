import os
import time
from typing import List, Tuple


ANNOTATIONS_PATH = os.getenv("ANNOTATIONS_PATH")


def parse_annotation(annotation: str) -> Tuple[str, str]:
    k, v = annotation.split("=")
    return k, v.strip()


def get_feature_flags() -> List[str]:
    with open(ANNOTATIONS_PATH, "r") as file:
        annotations = [parse_annotation(line) for line in file]
        print("annotations")
        print(annotations)
        feature_flags = filter(lambda x: "feature-" in x[0], annotations)
        return list(feature_flags)


if __name__ == "__main__":
    while True:
        time.sleep(5)
        print(get_feature_flags())
