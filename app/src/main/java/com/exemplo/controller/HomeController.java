package com.exemplo.controller;

import java.io.Serializable;
import javax.faces.view.ViewScoped;
import javax.inject.Named;

@Named("homeController")
@ViewScoped
public class HomeController implements Serializable {

    private static final long serialVersionUID = 1L;

    public String getMensagem() {
        return "Olá, mensagem vinda do bean!";
    }

    public String executar() {
        System.out.println("passei aqui");
        return null;
    }
}