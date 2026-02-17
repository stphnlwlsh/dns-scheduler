use dns_scheduler::{
    domain::DnsAction,
    handlers::{set, toggle},
};

fn main() {
    let provider = dns_scheduler::providers::next_dns::client::NextDNSClient::new()
        .expect("Failed to create DNS client");

    let port = std::env::var("PORT").unwrap_or_else(|_| "3003".to_string());
    let addr = format!("0.0.0.0:{}", port);
    let server = tiny_http::Server::http(addr).unwrap();

    let deny_list = std::env::var("DOMAIN_DENY_LIST").unwrap_or_default();
    let allow_list = std::env::var("DOMAIN_ALLOW_LIST").unwrap_or_default();

    for request in server.incoming_requests() {
        match (request.method(), request.url()) {
            (&tiny_http::Method::Get, "/enable") => handle_request(
                set::set_dns_settings(
                    &provider,
                    DnsAction::Enable,
                    allow_list.clone(),
                    deny_list.clone(),
                ),
                request,
            ),
            (&tiny_http::Method::Get, "/disable") => handle_request(
                set::set_dns_settings(
                    &provider,
                    DnsAction::Disable,
                    allow_list.clone(),
                    deny_list.clone(),
                ),
                request,
            ),
            (&tiny_http::Method::Get, "/toggle") => {
                handle_request(toggle::toggle_dns_settings(&provider), request)
            }
            _ => {
                let response =
                    tiny_http::Response::from_string("not implemented").with_status_code(501);
                request.respond(response).unwrap();
            }
        }
    }
}

fn handle_request(
    result: Result<String, dns_scheduler::domain::DnsError>,
    request: tiny_http::Request,
) {
    let response = match result {
        Ok(msg) => tiny_http::Response::from_string(msg).with_status_code(200),
        Err(err) => tiny_http::Response::from_string(err.to_string()).with_status_code(500),
    };
    request.respond(response).unwrap();
}
