function timings()
    
    clearvars
    nIters = 1000; 

    name2 = 'post2 (plain matlab)';
    t0 = tic;
    for i = 1:nIters
        net = sig.Net();
        a = 5; b = 2; c = 8; % Some constants to use in our equation
        x = net.origin('x');
        y = a * (x ^ 2) + b * x + c;
        x.post2(3)
    end
    te_post2 = toc(t0); % time elapsed (post2, matlab only)
   
    y.node

   %% *************************************************** %%

    clearvars -except te_post2 nIters name2

    name = 'post (mexnet)';
    t0 = tic;
    for i = 1:nIters
        net = sig.Net();
        a = 5; b = 2; c = 8; % Some constants to use in our equation
        x = net.origin('x');
        y = a * (x ^ 2) + b * x + c;
        x.post(3)
    end
    te_post = toc(t0); % time elapsed (post, mexnet)

    %% **************************************************** %%
    show_result(nIters, name2, name, te_post2, te_post);

end


function show_result(nIters, name2, name, te_post2, te_post)
    usecPerOp = (te_post2 * 10^6) / nIters;
    fprintf('%-30s  %12.9f  microsecs per iter \n', [name2 ':'], usecPerOp);

    usecPerOp = (te_post * 10^6) / nIters;
    fprintf('%-30s  %12.9f  microsecs per iter \n', [name ':'], usecPerOp);
end