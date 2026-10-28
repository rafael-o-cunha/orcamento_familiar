package com.exemplo.controller;

import java.io.Serializable;
import javax.faces.application.FacesMessage;
import javax.faces.context.FacesContext;

public abstract class BaseController implements Serializable {

    private static final long serialVersionUID = 1L;

    protected void showMessageInfo(String msg) {
        addMessage(FacesMessage.SEVERITY_INFO, "Info", msg);
    }

    protected void showMessageSuccess(String msg) {
        // JSF não tem severidade SUCCESS; por convenção usa-se INFO para sucesso
        addMessage(FacesMessage.SEVERITY_INFO, "Sucesso", msg);
    }

    protected void showMessageWarn(String msg) {
        addMessage(FacesMessage.SEVERITY_WARN, "Atenção", msg);
    }

    protected void showMessageError(String msg) {
        addMessage(FacesMessage.SEVERITY_ERROR, "Erro", msg);
    }

    private void addMessage(FacesMessage.Severity severidade, String titulo, String detalhe) {
        FacesContext.getCurrentInstance().addMessage(null, new FacesMessage(severidade, titulo, detalhe));
    }
}