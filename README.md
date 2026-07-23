# Описание
Реализована демонстрация полного цикла CI/CD на примере готового проекта [Time Tracker](https://github.com/taylor-training/time-tracker)

Java (Maven) application for tracking time on the job

Pipeline сборки и тестирования реализован на Jenkins. В процессе выполнения pipeline происходит:
- проверка репозитория на изменения
- получение последней версии проекта
- сборка,
- тестирование,
- создание Docker-образа из Docker файла, 
- Docker-образ заливается в хранилище ghcr.io
- Разворачивание в Kubernetis сервиса проекта из хранилища ghcr.io

Системы мониторинга и логирования разворачиваются с помощью Docker compose.

Blackbox Exporter выполняет внешний HTTP health-check через опубликованный Kubernetes NodePort. Данные мониторинга собираются в Prometheus и с помощью Grafana отображатся на dashboard.

Для системы логирования используется fluent-bit, который располагается в Kubernetis. Он собирает логи и доставляет их в Elasticsearch. Для просмотра, поиска и анализа логов из Elasticsearch используется Kibana.

# Устройство репозитория
```
time-tracker-devops/
├── Dockerfile
├── Jenkinsfile
├── k8s/
│   ├── deployment.yaml.template
│   └── service.yaml
├── infra/
│   ├── deploy_infra.sh
│   ├── docker-compose.yaml
│   ├── undeploy_infra.sh
│   ├── jenkins/
│   │   ├── DockerFile-jenkins-agent-maven
│   │   ├── DockerFile-jenkins-server
│   │   └── ja.env
│   ├── kubernetis/
│   │   ├── 01-kind-config.yaml
│   │   ├── 02-namespace.yaml
│   │   ├── fluent-bit.yaml
│   │   ├── k8s.env
│   │   └── k8s.sh
│   └── monitoring/
│       ├── blackbox/
│       │   └── blackbox.yaml
│       ├── grafana/
│       │   ├── dashboards/
│       │   │   └── time-tracker_00.json
│       │   └── provisioning/
│       │       ├── dashboards/
│       │       │   └── dashboard.yaml
│       │       └── datasources/
│       │           └── prometheus.yaml
│       └── prometheus/
│           └── prometheus.yaml
├── core/
├── web/
└── pom.xml
```

Описание:
- `Dockerfile` содержит инструкции для сборки Docker-образа в процессе выполнения pipeline
- `Jenkinsfile` pipeline Jenkins
- `k8s/` Kubernetis манифесты 
- `infra/deploy_infra.sh` - скрипт для разворачивания инфраструктуры
- `infra/undeploy_infra.sh` - скрипт для сворачивания инфраструктуры (удаления контейнеров, volume не удаляются)
- `infra/docker-compose.yaml` - docker-compose-файл для разворачивания инфраструктуры
- `infra/jenkins/` - файлы Jenkins
- `infra/kubernetis/` - файлы Kubernetis
- `infra/logging/` - файлы системы логирования: elasticksearch, kibana
- `infra/monitoring/` - файлы системы мониторинга: prometheus, grafana, cadvisor, blackbox
- `core/`, `web/` и `pom.xml` - директории и файл, составляющие сам проект

# Требования
Должны быть установлены:
- Docker`
- Kind
- Helm`
- Kubectl
- yq
Для сборки приложения
* JDK 17+
* Maven 3.8+

Установка `yq` добавлена в `infra/deploy_infra.sh`, тут приведены команды установки
```bash
sudo wget -O /usr/local/bin/yq \
    https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64

sudo chmod +x /usr/local/bin/yq
```
# Доступ к сервисам
После разворачивания инфраструктуры, сервисы будут доступны на следующих адресах

| Сервис                  | URL                      |
| ----------------------- | ------------------------ |
| Приложение time-tracker | `http:/localhost:30080/` |
| Jenkins                 | `http:/localhost:8080`   |
| SonarQube               | `http:/localhost:9000`   |
| ElasticSearch           | `http:/localhost:9200`   |
| Kibana                  | `http:/localhost:5601`   |
| Prometheus              | `http:/localhost:9090`   |
| Grafana                 | `http:/localhost:3000`   |
| cAdvisor                | `http:/localhost:8081`   |
| Blackbox                | `http:/localhost:9115`   |


# Разворачивание инфраструктуры
Для разворачивания инфраструктуры необходимо.

Клонировать репозиторий и перейти в папку проекта:
```bash
git clone https://github.com/needleback/time-tracker-devops.git
cd time-tracker-devops/
```

Заполнить `k8s.env` для создания секрета kubernetis для доступа  к `ghcr.io`
```bash
vim infra/kubernetis/k8s.env
```

Для удобства развёртывания воспользоваться скриптом
```bash
cd infra/
chmod +x deploy_infra.sh 
chmod +x undeploy_infra.sh 
chmod +x kubernetis/k8s.sh 
./deploy_infra.sh
```

Далее, после разворачивания инфраструктуры, необходимо ее настроить.

## Jenkins

### Добавляем SonarQube
В Jenkins устанавливаем плагин
```
http://localhost:8080/
Manage Jenkins -> Plugins -> Available plugins -> SonarQube Scanner
```

В SonarQube генерируем токен и копируем полученный токен.
```
http://localhost:9000/
Account -> My account -> Security -> Generate Tokens
```

Добавляем токен SonarQube авторизации в Jenkins
```
http://localhost:8080/
Manage Jenkins -> Credentials -> Add Credentails -> type:"Secret text"

Secret: <скопированный выше секрет>
ID: sonar
```

Добавляем сервер SonarQube в Jenkins
```
http://localhost:8080/
Manage Jenkins -> System -> SonarQube servers
```

Добавляем 
```
name: SonarServer
url: http://localhost:9000/
Server authentication token: sonar
```

Добавляем веб-хук в SonarQube
```
Administration Configuration -> Webhooks -> Create

Name: Jenkins
url: http://localhost:8080/sonarqube-webhook/

```

### Добавляем агента
Агент развернулся из docker-compose, но его нужно добавить в Jenkins.
```
http://localhost:8080/
Manage Jenkins -> Nodes -> New Node
Name: maven-agent-01
Type: Permanent Agent

Remote root directory: /home/jenkins/agent
Labels: maven
```

Далее смотрим статус агента и берем оттуда значение `-secret`
И заполняем `JENKINS_SECRET` в `infra/jenkins/ja.env`
После чего перезапускаем агента
```bash
docker compose up -d jenkins-agent
```

### Добавляем credentials
Для того, что бы предоставить pipeline Jenkins доступ к репозиторию github.com. Создаем Token-PAT (classic)
```
https://github.com
Settings -> Credentials -> Personal access tokens (classic) -> Generate new token

Права:
write: packages
read: packages
```

Добавляем его в Jenkins
```
http://localhost:8080/
Jenkins -> Manage Jenkins -> Credentials -> Add Credentials -> type:"Username with password"

username: <YOU_USERNAME>
password: <YOU_PAT>
ID: "ghcr-credentials"
```

### Создание pipeline
Создаем Pipeline в Jenkins
```
http://localhost:8080/
Jenkins -> New Item -> name:time-tracker-devops -> type:Pipeline ->
```

Настраиваем триггер
```
Triggers -> Poll SCM ->
```

Указываем где брать скрипт pipeline.
```
Pipeline -> Definition -> Pipeline script from SCM

SCM: Git
Repository URL: https://github.com/needleback/time-tracker-devops.git
Credentials: <при необходимости>
Branch Specifier: main
Script Path: Jenkinsfile
```

## Monitoring
Для демонстрации мониторинга используется Grafana, все настройки подключены из конфигурационных файлов
```
http://localhost:3000/

Grafana -> Dashboards -> Time-traker App -> App time-tracker
```

## Logging
Для демонстрации логирование используется Kibana, все настройки подключены из конфигурационных файлов
```
http://localhost:5601/
Kibana -> Stack Management -> Index Patterns -> Create Index pattern

name: time-tracker-*
Timestamp field: @timestamp

Kibana -> Discover
```

# Разворачивание приложения
Во время выполнения Jenkins-pipeline приложение будет развернуто автоматически в Kubernetis из образа в `ghcr.io`. Но при желании можно развернуть локально вручную. Для этого необходимо:

Склонировать репозиторий и перейти в него
```bash
git clone https://github.com/needleback/time-tracker-devops.git
cd time-tracker-devops/
```

Выполнить подготовку манифеста из шаблона, указав вместо `<IMAGE_TAG>` желаемый тег, либо ничего не указывает, если хотим получить последнюю версию
```bash
sed "s|IMAGE_PLACEHOLDER|ghcr.io/needleback/time-tracker-devops:<IMAGE_TAG>|g" \
    k8s/deployment.yaml.template > k8s/deployment.yaml
```

Затем применить манифест
```bash
kubectl apply -f k8s/
```

Подождать пока скачается и проверить, что все развернулось
```bash
kubectl -n diplom get all
```

# Правила внесения изменения
Общий процесс:
1. Из ветки `main` необходимо создать ветку `feature`
2. Вносим изменения
    1. Изменения в коде приложения: 
        - `core/`
        - `web/`
        - `pom.xml`
    2. Изменения манифеста разворачивания приложения: 
        - `k8s/`
    3. Изменения Dockerfile для сборки приложения:
        - `Dockerfile`
    4. Изменения в логировании:
        - `infra/kubernetis/fluent-bit.yaml`
        - `infra/logging/`
    5. Изменения в мониторинге
        - `infra/monitoring/`
    6. Изменения в Jenkins
        - `infra/jenkins/`
        - `Jenkinsfile`
3. Если изменения были внесены в инфраструктуру, то для проверки локально запускаем скрипты для пересоздания и переходим к п.5
    - `./infra/undeploy_infra.sh`
    - `./infra/deploy_infra.sh`
4. Если изменения были внесены в код приложения, то срузу переходим к п.5. А после отправки изменений в репозиторий по триггеру Jenkins запустится pipeline, который выполнит полный цикл CI/CD.
5. Коммитим и создаем Pull Request
6. Merge в главную ветку после review

# Версионирование
Для учебной работы в качестве версионирования был использован `Jenkins BUILD_NUMBER`, который генерирует новую версию при каждой сборке билда.

# Автор CI/CD
needleback