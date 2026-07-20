FROM maven:3.9-eclipse-temurin-21 AS build
RUN mkdir -p /workspace
WORKDIR /workspace
COPY . .
RUN mvn clean package -DskipTests

FROM tomcat:10-jdk21-temurin
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=build \
    /workspace/web/target/*.war \
    /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
CMD ["catalina.sh", "run"]
