{#
    dbtの既定では、カスタムスキーマ名は「<targetのスキーマ>_<カスタムスキーマ名>」に連結される。
    本基盤のスキーマ（STAGING/INTERMEDIATE/MARTS）は作成済みで、TRANSFORMER_*ロールには
    スキーマの作成権限がないため、カスタムスキーマ名をそのままスキーマ名として使う。
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
