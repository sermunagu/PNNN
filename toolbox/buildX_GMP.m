function [Xmat, Rmat] = buildX_GMP(x, n, Qpmax, Qnmax, Ka, Kb, Kc, La, Lb, Lc, Mb, Mc)
% buildX_GMP Generates the measurement matrix of a GMP model
% D. R. Morgan, Z. Ma, J. Kim, M. G. Zierdt and J. Pastalan, "A Generalized
% Memory Polynomial Model for Digital Predistortion of RF Power Amplifiers,"
% in IEEE Transactions on Signal Processing, vol. 54, no. 10, pp. 3852-3860,
% Oct. 2006
%
% [Xmat, Rmat] = function buildX_GMP(x, n, Qpmax, Qnmax, Ka, Kb, Kc, La, Lb, Lc, Mb, Mc)

Regr_a = []; Regr_b = []; Regr_c = [];
Xa = []; Xb = []; Xc = [];

indk = 0;
for k = 1:length(Ka)
    for l = 0:La(k)
        indk = indk + 1;

        Xa(:,indk) = x(n(1+Qpmax-l:end-Qnmax-l)).*(abs(x(n(1+Qpmax-l:end-Qnmax-l))).^(Ka(k))); %Qpmax y Qnmas se utilizan para evitar indices fuera de rango una vez l vaya creciendo
        if(Ka(k)~=0)
            Regr_a{indk} = sprintf('x(n-%d)|x(n-%d)|^{%d}',l,l,Ka(k));
        else
            Regr_a{indk} = sprintf('x(n-%d)',l);
        end
    end
end

% Parte B y C: Son los términos cruzados que incorporan efectos de memoria adicionales, en los cuales la magnitud se toma en un retardo distinto al de la señal lineal. La idea es modelar interacciones temporales más complejas.
indk = 0;
for k = 1:length(Kb)
    for l = 0:Lb(k)
        for m = 1:Mb(k)
            indk = indk + 1;
            Xb(:,indk) = x(n(1+Qpmax-l:end-Qnmax-l)).*(abs(x(n(1+Qpmax-l-m:end-Qnmax-l-m))).^(Kb(k))); % Términos cruzado donde la parte no lineal (la magnitud elevada a Kb) aparece retrasada frente a la señal lineal.
            Regr_b{indk} = sprintf('x(n-%d)|x(n-%d)|^{%d}',l,l+m,Kb(k));
        end
    end
end

indk = 0;
for k = 1:length(Kc)
    for l = 0:Lc(k)
        for m = 1:Mc(k)
            indk = indk + 1;
            Xc(:,indk) = x(n(1+Qpmax-l:end-Qnmax-l)).*(abs(x(n(1+Qpmax-l+m:end-Qnmax-l+m))).^(Kc(k))); % Términos cruzado donde la parte no lineal (la magnitud elevada a Kb) aparece adelantada frente a la señal lineal.
            Regr_c{indk} = sprintf('x(n-%d)|x(n-%d)|^{%d}',l,l-m,Kc(k));
        end
    end
end

Xmat = [Xa,  Xb, Xc]; % Se asignan en columnas sucesivas (analíticamente es como una suma)
Rmat = [Regr_a,  Regr_b, Regr_c]';
end