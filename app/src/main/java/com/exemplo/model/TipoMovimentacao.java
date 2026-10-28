package com.exemplo.model;

public enum TipoMovimentacao {

    TODOS("Todos"),
    DESPESA("Despesas"),
    RECEITA("Receitas"),
    MOVIMENTACAO("Movimentação");

    private final String label;

    TipoMovimentacao(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }
}