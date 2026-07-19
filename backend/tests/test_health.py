def test_health_returns_ok_when_db_is_reachable(client):
    response = client.get("/api/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
