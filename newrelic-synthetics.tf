# Monitor externo de disponibilidade.
#
# Cobre o que nenhum sinal de dentro do cluster cobre: resolução de DNS,
# validade do certificado e o caminho pela internet pública até o API Gateway.
# Um pod pode estar pronto e a aplicação continuar inalcançável — é essa
# diferença que este monitor mede.
#
# A frequência é baixa porque o free tier dá 500 checks por mês; a explicação
# da conta está na variável `synthetics_period`. A detecção rápida de queda fica
# com as condições internas, que rodam a cada minuto sem consumir cota.

resource "newrelic_synthetics_monitor" "healthcheck" {
  count = var.synthetics_uptime_url != "" ? 1 : 0

  account_id = var.newrelic_account_id
  name       = "${local.cluster_name} — healthcheck"
  type       = "SIMPLE"
  status     = "ENABLED"
  period     = var.synthetics_period
  uri        = var.synthetics_uptime_url

  # Uma localização só. Cada localização adicional multiplica o consumo de cota
  # pelo mesmo fator, e três regiões a cada 6h gastariam o mês em dez dias.
  locations_public = ["AWS_US_EAST_1"]

  # Redirecionamento silencioso para uma página de erro do balanceador devolve
  # 200; sem esta verificação o monitor ficaria verde com a aplicação fora.
  verify_ssl                = true
  treat_redirect_as_failure = true

  # Tags padrão do projeto (environment/project), as mesmas de toda a
  # telemetria. O monitor aceita tag direto no recurso; dashboard e condições
  # recebem as suas em newrelic-tags.tf.
  dynamic "tag" {
    for_each = var.newrelic_tags

    content {
      key    = tag.key
      values = [tag.value]
    }
  }
}

resource "newrelic_nrql_alert_condition" "uptime_externo" {
  count = var.synthetics_uptime_url != "" ? 1 : 0

  account_id  = var.newrelic_account_id
  policy_id   = newrelic_alert_policy.oficina.id
  type        = "static"
  name        = "Uptime — healthcheck externo falhando"
  description = "O endpoint público não respondeu com sucesso a partir da internet."

  # `event_timer` usa `aggregation_timer`; `aggregation_delay` é das
  # agregações event_flow/cadence.
  enabled                      = true
  aggregation_method           = "event_timer"
  aggregation_timer            = 300
  violation_time_limit_seconds = 86400

  # A janela acompanha a frequência do monitor: avaliar em 5 minutos um check
  # que roda a cada 6 horas deixaria a condição sem dado quase o tempo todo.
  aggregation_window = 21600

  nrql {
    query = <<-NRQL
      SELECT count(*)
      FROM SyntheticCheck
      WHERE monitorName = '${local.cluster_name} — healthcheck'
        AND result = 'FAILED'
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 21600
    threshold_occurrences = "ALL"
  }
}
