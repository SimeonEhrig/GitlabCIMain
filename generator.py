import yaml
import sys


def generate_job(name: str):
    return {
        name: {
            "image": "alpine:latest",
            "script": [f'echo "I am running config: {name}"'],
        }
    }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Error ether set argument conf1 or conf2", file=sys.stderr)
        sys.exit(1)

    if sys.argv[1] != "conf1" and sys.argv[1] != "conf2":
        print("Argument is not conf1 or conf2", file=sys.stderr)
        sys.exit(1)

    print(yaml.dump(generate_job(sys.argv[1])))
