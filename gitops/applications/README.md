# Applications

[Open Application Model (OAM)](https://kubevela.io/docs/platform-engineers/oam/oam-model)

## Microservice (Backend)

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: <name_of_the_microservice>
spec:
  components:
    - name: <name_of_the_microservice>
      type: microservice
      properties:
        image: <image>
        feature-toggles:
          feature-foo: "off" # feature-<name_of_feature>
          feature-bar: "off" # "on" or "off"
```
