import os
import time


ANNOTATIONS_PATH = os.getenv("ANNOTATIONS_PATH")


def parse_annotation(annotation: str):
    k, v = annotation.split("=")
    return k, v.strip().replace("\"", "")


def get_feature_flags() -> dict:
    with open(ANNOTATIONS_PATH, "r") as file:
        annotations = [parse_annotation(line) for line in file]
        feature_flags = filter(lambda x: "feature-" in x[0], annotations)
        return dict(feature_flags)


if __name__ == "__main__":
    while True:
        time.sleep(1)
        print(get_feature_flags())
