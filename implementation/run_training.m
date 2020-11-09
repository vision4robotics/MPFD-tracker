function g_f = run_training( xf, use_sz , h_ideal ,params, mu , yf,w  ,lambda_1,lambda_2,zf_new ,zf, fff )

% ADMM parameters
alpha = 10;
gamma=params.gamma;
gamma_max=params.gamma_max;

T = prod(use_sz);

% ADMM solution
g_f = single(zeros(size(xf)));
h_f = single(zeros(size(xf)));
l_f = single(zeros(size(xf)));
xpf = single(zeros(size(xf)));

Sxy = bsxfun(@times, xf, conj(yf));
Sxx = bsxfun(@times, xf, conj(xf));
Szn = bsxfun(@times, zf_new, conj(zf_new));
Sznz = bsxfun(@times, zf_new, conj(zf));


% ADMM iterations
iter = 1;
while (iter <= params.admm_iterations)
  
    Sxpy = bsxfun(@times, xpf, conj(yf));
    Sxpxp = bsxfun(@times, xpf, conj(xpf));
    
    
     g_f = bsxfun(@rdivide, ...
		    Sxy +  lambda_1 * Sxpy  + gamma * T * h_f -  T * l_f  , ...
		    Sxx +  lambda_1 * Sxpxp + gamma * T );
    

    lhd= 1 ./  (params.admm_lambda * w .^2 + gamma*T + mu ); 
    X = ifft2( T* l_f + T* gamma * g_f + mu * h_ideal)  ;
    h=bsxfun(@times,lhd,X);
    h_f = fft2(h);
     

    
    if fff==0
        xpf = bsxfun(@rdivide, ...
        lambda_1 * bsxfun(@times, g_f, yf) + lambda_2 * Sznz .*xf  , ...
        lambda_2 *  Szn + lambda_1 * bsxfun(@times, g_f, conj(g_f)) );
    end



    
    l_f = l_f + (gamma * (g_f - h_f));
    
    gamma = min(gamma_max, alpha * gamma);

    
    iter = iter + 1;

end

end
