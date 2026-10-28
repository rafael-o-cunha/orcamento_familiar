package com.exemplo.controller;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.List;

import javax.annotation.PostConstruct;
import javax.faces.view.ViewScoped;
import javax.inject.Named;

import org.primefaces.event.SelectEvent;
import org.primefaces.event.UnselectEvent;

import com.exemplo.filtro.MovimentacaoFiltro;
import com.exemplo.model.Movimentacao;
import com.exemplo.model.TipoMovimentacao;

@Named("movimentacaoController")
@ViewScoped
public class MovimentacaoController extends BaseController implements Serializable {

    private static final long serialVersionUID = 1L;

    private MovimentacaoFiltro filtro = new MovimentacaoFiltro();

    private List<Movimentacao> movimentacoes;
    private List<Movimentacao> baseSimulada;
    private Movimentacao movSelecionado;

    @PostConstruct
    public void init() {
        baseSimulada = criarListaSimulada();
        movimentacoes = new ArrayList<>(baseSimulada);
    }

    public List<TipoMovimentacao> getTiposDisponiveis() {
        return Arrays.asList(TipoMovimentacao.values());
    }
    
    public MovimentacaoFiltro getFiltro() {
    	return filtro;
    }
    
    public void setFiltro(MovimentacaoFiltro filtro) {
    	this.filtro = filtro;
    }

    public List<Movimentacao> getMovimentacoes() {
    	return movimentacoes;
    }
    
    public void setMovimentacoes(List<Movimentacao> movimentacoes) {
    	this.movimentacoes = movimentacoes;
    }

    public Movimentacao getMovSelecionado() {
    	return movSelecionado;
    }
    
    public void setMovSelecionado(Movimentacao movSelecionado) {
    	this.movSelecionado = movSelecionado;
    }

    public void filtrar() {
        List<Movimentacao> resultado = new ArrayList<>();

        for (Movimentacao m : baseSimulada) {
            if (filtro.aceita(m)) {
                resultado.add(m);
            }
        }

        movimentacoes = resultado;

        if (resultado.isEmpty()) {
            showMessageWarn("Nenhuma movimentação encontrada com os critérios informados.");
        }
        else {
            showMessageSuccess("Busca concluída: " + resultado.size() + " registro(s) encontrado(s).");
        }

        // >>> Quando o datasource funcionar, a chamada real fica assim, um argumento só:
        // movimentacoes = movimentacaoDAO.buscarPorFiltro(filtro);
    }

    public void limparFiltro() {
        filtro.limpar();
        movimentacoes = new ArrayList<>(baseSimulada);
        showMessageInfo("Filtro limpo.");
    }

    public void onRowSelect(SelectEvent event) {
        this.movSelecionado = (Movimentacao) event.getObject();
        showMessageSuccess("Linha selecionada: " + movSelecionado.getDescricao());
    }

    public void onRowUnselect(UnselectEvent event) {
        showMessageWarn("Linha DESselecionada");
        this.movSelecionado = null;
    }

    private List<Movimentacao> criarListaSimulada() {
        List<Movimentacao> lista = new ArrayList<>();
        Calendar c = Calendar.getInstance();

        lista.add(new Movimentacao(1L, "Compra de material", TipoMovimentacao.DESPESA, c.getTime(), new BigDecimal("150.00")));

        c.add(Calendar.DAY_OF_MONTH, -3);
        lista.add(new Movimentacao(2L, "Venda de serviço", TipoMovimentacao.RECEITA, c.getTime(), new BigDecimal("1200.00")));

        c.add(Calendar.DAY_OF_MONTH, -7);
        lista.add(new Movimentacao(3L, "Transferência entre contas", TipoMovimentacao.MOVIMENTACAO, c.getTime(), new BigDecimal("300.00")));

        c.add(Calendar.DAY_OF_MONTH, -15);
        lista.add(new Movimentacao(4L, "Pagamento de aluguel", TipoMovimentacao.DESPESA, c.getTime(), new BigDecimal("2500.00")));

        return lista;
    }

}