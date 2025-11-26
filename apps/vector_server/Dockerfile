FROM qdrant/qdrant:v1.16

COPY vector_server/init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 6333

ENTRYPOINT ["/init.sh"]
CMD ["./qdrant"]
