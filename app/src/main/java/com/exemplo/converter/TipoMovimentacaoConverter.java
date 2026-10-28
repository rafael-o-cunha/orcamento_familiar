package com.exemplo.converter;

import javax.faces.component.UIComponent;
import javax.faces.context.FacesContext;
import javax.faces.convert.Converter;
import javax.faces.convert.ConverterException;
import javax.faces.convert.FacesConverter;

import com.exemplo.model.TipoMovimentacao;

@FacesConverter("tipoMovimentacaoConverter")
public class TipoMovimentacaoConverter implements Converter {

    @Override
    public Object getAsObject(FacesContext context, UIComponent component, String value) {
        if (value == null || value.trim().isEmpty()) {
            return null;
        }
        return TipoMovimentacao.valueOf(value); // "DESPESA" -> enum
    }

    @Override
    public String getAsString(FacesContext context, UIComponent component, Object value) {
        if (value == null) {
            return "";
        }
        if (value instanceof TipoMovimentacao) {
            return ((TipoMovimentacao) value).name(); // enum -> "DESPESA"
        }
        throw new ConverterException("Valor não é um TipoMovimentacao: " + value);
    }
}