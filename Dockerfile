# BUILDER 1 #
###########
# pull official base image
FROM python:3.8.2-slim-buster as builder
# set work directory
WORKDIR /usr/src/app
# set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
# install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc
# lint
RUN pip install --upgrade pip
RUN pip install flake8
COPY . /usr/src/app/
# RUN flake8 --ignore=E501,F401 .
# install python dependencies
COPY ./requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels -r requirements.txt
#########
# FINAL #

# BUILDER 2#
###########
FROM ubuntu:20.04 as base
#########
# FINAL #



# Trying multi-stage build
FROM base
ENV LANG=C.UTF-8
USER root
ENV APP_HOME /app
ENV CONFIGURATION_SETUP="config.ProductionConfig"
# tzdata, required for opencv, will not install without these envrionment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York
WORKDIR $APP_HOME
COPY . ./


COPY --from=builder /usr/src/app/wheels /wheels
COPY --from=builder /usr/src/app/requirements.txt .
# 60% reduction in size due to no-install-recommends https://ubuntu.com/blog/we-reduced-our-docker-images-by-60-with-no-install-recommends
# -y is necessary to install quietly
# useradd is necessary because of security
RUN  apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    libglib2.0-dev\
    libgtk2.0-dev\    
    python3 \
    python3-distutils \
    python3-pip && \
    mkdir /var/run/sshd && \
    echo 'root:mypassword' | chpasswd && \ 
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config &&\
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd &&\
    # useradd --user-group --system --create-home --no-log-init app && \    
    chown -R app:app $APP_HOME && \    
    pip3 install --no-cache /wheels/* && \
    rm -rf /var/lib/apt/lists/* 


EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
# USER app
# CMD ["gunicorn", "--bind", "0.0.0.0:$PORT", "--config", "gunicorn.conf.py" ,"wsgi:app"]
# CMD exec gunicorn --config gunicorn.conf.py --bind 0.0.0.0:$PORT wsgi:app
