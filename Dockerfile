FROM jupyter/scipy-notebook

USER root

RUN apt-get update
RUN apt-get install awscli -y

USER jovyan

COPY requirements.txt .
RUN conda install --yes --file requirements.txt

COPY bootstrap.sh /usr/local/bin/

ENTRYPOINT ["bash", "bootstrap.sh"]
