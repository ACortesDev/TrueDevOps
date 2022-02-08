import os
import time
from typing import List


ANNOTATIONS_PATH = os.getenv("ANNOTATIONS_PATH")


def get_pod_annotations() -> List[str]:
    with open(ANNOTATIONS_PATH, "r") as file:
        return [line for line in file]


if __name__ == "__main__":
    while True:
        time.sleep(5)
        print(get_pod_annotations())
