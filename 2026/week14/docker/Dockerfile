FROM python:3.13
WORKDIR /usr/local/app
COPY requirements.txt ./
RUN pip install -r requirements.txt
COPY . ./src
RUN useradd waff && mkdir /data && chown waff /data
USER waff
ENV PORT=5000 GREETING=hello
EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD curl -f localhost:$PORT/health || exit 1

CMD gunicorn --bind 0.0.0.0:$PORT --workers 3 --chdir src app:app
