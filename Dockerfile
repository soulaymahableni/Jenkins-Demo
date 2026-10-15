FROM eclipse-temurin:17-jdk
VOLUME /tmp
COPY target/devOpsDemo-0.0.1-SNAPSHOT.jar /app.jar
EXPOSE 2222
CMD ["java", "-jar", "/app.jar"]
