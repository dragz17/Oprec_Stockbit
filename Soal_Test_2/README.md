# Section 2. CI/CD Test

## Goals

User will create CI/CD flow about web application, we will use nginx as webserver and simply add hello.txt into the image.

Then, push the image into registry then deploy the apps to our instance.

## Prerequisites
- Instance for CI/CD Tools, e.g Jenkins
- Dependencies like Git, Docker, Java 8 SE
- Container Registry
- SCM, e.g GitHub

## Proof of Concept
### Repo's side
We will need to add config to change root of our webserver. Let's name it default.conf
```
server {
    listen       80;
    listen  [::]:80;
    server_name  localhost;

    location / {
        root   /var/www/;
        index  index.html index.htm;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
```

Then, we will need to add index.html (optional) and hello.txt. Just use simple text.  

index.html
```
under construction!
```
hello.txt
```
Hi, I'm Boy.
Nice to meet you!
```

After that, we can setup the Dockerfile.
```
FROM nginx:latest
COPY ./default.conf /etc/nginx/conf.d/default.conf
COPY ./index.html /var/www/index.html
COPY ./hello.txt /var/www/hello.txt
```

Our application is ready to integrate.

### CI/CD Tool's side
