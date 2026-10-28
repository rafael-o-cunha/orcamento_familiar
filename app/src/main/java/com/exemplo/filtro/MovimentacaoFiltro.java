package com.exemplo.filtro;

import java.io.Serializable;
import java.util.Date;
import java.util.List;

import com.exemplo.model.Movimentacao;
import com.exemplo.model.TipoMovimentacao;

public class MovimentacaoFiltro implements Serializable {

    private static final long serialVersionUID = 1L;

    private String descricao;
    private Date dataInicio;
    private Date dataFim;
    private List<TipoMovimentacao> tipos;

    public boolean temDescricao() {
        return descricao != null && !descricao.trim().isEmpty();
    }

    public boolean filtraPorTipo() {
        return tipos != null && !tipos.isEmpty() && !tipos.contains(TipoMovimentacao.TODOS);
    }

    public boolean aceita(Movimentacao m) {
        if (temDescricao() && !m.getDescricao().toLowerCase().contains(descricao.trim().toLowerCase())) {
            return false;
        }
        
        if (dataInicio != null && m.getData().before(dataInicio)) {
            return false;
        }
        
        if (dataFim != null && m.getData().after(dataFim)) {
            return false;
        }
        
        if (filtraPorTipo() && !tipos.contains(m.getTipo())) {
            return false;
        }
        
        return true;
    }

    public void limpar() {
        descricao = null;
        dataInicio = null;
        dataFim = null;
        tipos = null;
    }

    public String getDescricao() {
    	return descricao;
    }
    
    public void setDescricao(String descricao) {
    	this.descricao = descricao;
    }

    public Date getDataInicio() {
    	return dataInicio;
    }
    
    public void setDataInicio(Date dataInicio) {
    	this.dataInicio = dataInicio;
    }

    public Date getDataFim() {
    	return dataFim;
    }
    
    public void setDataFim(Date dataFim) {
    	this.dataFim = dataFim;
    }

    public List<TipoMovimentacao> getTipos() {
    	return tipos;
    }
    
    public void setTipos(List<TipoMovimentacao> tipos) {
    	this.tipos = tipos;
    }
}