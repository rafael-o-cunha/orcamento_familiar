package com.exemplo.model;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.Date;

public class Movimentacao implements Serializable {

    private static final long serialVersionUID = 1L;

    private Long id;
    private String descricao;
    private TipoMovimentacao tipo;
    private Date data;
    private BigDecimal valor;

    public Movimentacao(Long id, String descricao, TipoMovimentacao tipo, Date data, BigDecimal valor) {
        this.id = id;
        this.descricao = descricao;
        this.tipo = tipo;
        this.data = data;
        this.valor = valor;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getDescricao() { return descricao; }
    public void setDescricao(String descricao) { this.descricao = descricao; }

    public TipoMovimentacao getTipo() { return tipo; }
    public void setTipo(TipoMovimentacao tipo) { this.tipo = tipo; }

    public Date getData() { return data; }
    public void setData(Date data) { this.data = data; }

    public BigDecimal getValor() { return valor; }
    public void setValor(BigDecimal valor) { this.valor = valor; }
}