function [ftten,final_loglik,bic] = ...
    tucker_EM_aggregate(data,dataweight,core,maxiter,cate,tol,plot_figure,rawten)

if nargin == 3
    tol = 1e-7;
    plot_figure = false;
    cate = max(data);
end

[nobs,ndim] = size(data);

if plot_figure
    figure; colormap('parula');
end


idx = cell(ndim,1);
[idx{:}] = ind2sub(core,1:prod(core));

lambda = cell(ndim,1);
if nargin ~= 8
    for d = 1:ndim
        t = randgamma(ones(cate(d),core(d)));
        lambda{d} = bsxfun(@rdivide,t,sum(t,1)); %dirichlet uniform prior
    end
    pi_weight = randgamma(ones(1,prod(core)));
    pi_weight = pi_weight/sum(pi_weight);
else
    coret = reshape(double(rawten.core),1,[]);
    for d = 1:ndim
        t = rawten.U{d};
        w = sum(t,1);
        for e = 1:length(w);
            coret(idx{d}==e) =  coret(idx{d}==e)*w(e);
        end
        lambda{d} = bsxfun(@rdivide,t,sum(t,1));
    end
    coret = coret/sum(coret);
    pi_weight = coret;
end


final_loglik = nan(maxiter,1);
final_loglik(1) = -Inf;

coverg = 100;
iter = 1;

% begin of EM
while coverg > tol && iter < maxiter
    iter = iter+1;
    tempz0 = ones(nobs,prod(core));
    for d = 1:ndim
        tempz0 = times(tempz0,lambda{d}(data(:,d),idx{d}));
    end
    probz = bsxfun(@times,tempz0,pi_weight);

    Eik = bsxfun(@rdivide,probz,sum(probz,2));
    Eik = bsxfun(@times,Eik,dataweight);
    for d = 1:ndim
        tEik = zeros(nobs,core(d));
        for i = 1:core(d)
            tEik(:,i) = Eik*((idx{d}==i)');
        end
        tt = sum_eik(tEik,data(:,d),cate(d));
        lambda{d} = bsxfun(@rdivide,tt,sum(tt,1));
    end
    
    pi_temp = sum(Eik,1);
    pi_weight = pi_temp/sum(pi_temp);
    loglik = sum(dataweight.*log(sum(probz,2)));
    coverg = abs(loglik - final_loglik(iter-1));
    final_loglik(iter) = loglik;
    
    % display iteration
    if mod(iter-1,2) == 0 && plot_figure
        subplot(1,3,1);
        plot(lambda{1},'linewidth',2);
        disp(iter);
        subplot(1,3,2);
        bar(lambda{2,1}','stack'); ylim([0,1]); xlim([0,core(2)+1]);
        subplot(1,3,3);
        qq = -final_loglik;
        plot(qq,'-s','linewidth',2); xlim([1,iter+1]);
        drawnow;
    end
end

newcore = tensor(reshape(pi_weight,core));
ftten = ttensor(newcore,lambda{:});

disp(iter);
bic = 0;
