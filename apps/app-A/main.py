import os
import time


ANNOTATIONS_PATH = os.getenv("ANNOTATIONS_PATH")


def get_feature_flags():
    with open(ANNOTATIONS_PATH, "r") as file:
        return [line for line in file]


if __name__ == "__main__":
    print("Hello World!")
    while True:
        time.sleep(5)
        print(get_feature_flags())
