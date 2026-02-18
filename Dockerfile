FROM rust:1.93.0 AS builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:trixie-slim
WORKDIR /app
COPY --from=builder /app/target/release/dns-scheduler /app/dns-scheduler
EXPOSE 8080
CMD ["./dns-scheduler"]
