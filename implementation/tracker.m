% This function implements the ASRCF tracker.

function [results] = tracker(params)

num_frames     = params.no_fram;
newton_iterations=params.newton_iterations;
global_feat_params = params.t_global;
featureRatio = params.t_global.cell_size;
search_area = prod(params.wsize * params.search_area_scale);
pos         = floor(params.init_pos);
target_sz   = floor(params.wsize);



[currentScaleFactor,base_target_sz,reg_sz,sz,use_sz] = init_size(params,target_sz,search_area);
[y_0,cos_window] = init_gauss_win(params,base_target_sz,featureRatio,use_sz);
yf=fft2(y_0);
[features,im,colorImage] = init_features(params);
[ysf,scale_window,scaleFactors,scale_model_sz,min_scale_factor,max_scale_factor] = init_scale(params,target_sz,sz,base_target_sz,im);
% Pre-computes the grid that is used for score optimization
ky = circshift(-floor((use_sz(1) - 1)/2) : ceil((use_sz(1) - 1)/2), [1, -floor((use_sz(1) - 1)/2)]);
kx = circshift(-floor((use_sz(2) - 1)/2) : ceil((use_sz(2) - 1)/2), [1, -floor((use_sz(2) - 1)/2)])';
rect_position = zeros(num_frames, 4);
time = 0;
loop_frame = 1;
Vy=0;
Vx=0;
flm=params.flm;
ideal_filter_lb=cell(42,flm);
ideal_filter_score=zeros(42,flm);


for frame = 1:num_frames
    im = load_image(params,frame,colorImage);
    tic();  
%% main loop
    
    if  frame == 2
            mu = 0;
            lambda_1=0;
            lambda_2=0;
            fff=1;
            
    else
            mu=params.init_mu;
            lambda_1=params.lambda_1;
            lambda_2=params.lambda_2;
            fff=0;
    end
        
    if frame > 1
        
        pos_pre=pos;
        center=pos+[Vy Vx];
        pixel_template=get_pixels(im, center, round(sz*currentScaleFactor), sz);             
        xt=get_features(pixel_template,features,global_feat_params);
        xtf=fft2(bsxfun(@times,xt,cos_window));   
        
        if frame ==2        
            zf = xtf;
            zf_new = xtf;    

        else
            zf = zf_new;
            zf_new = xtf;
        end
        
        %when then new frame comes, extract the feature of the ROI, then train the filter
        g_f = run_training(xf,use_sz,h_ideal,params,mu,yf,w,lambda_1 ,lambda_2 ,zf_new,zf,fff);
        [pos,translation_vec,ideal_filter_lb,ideal_filter_score,h_ideal] = run_detection(params,im,center,xtf,currentScaleFactor,g_f,use_sz,ky,kx,newton_iterations,featureRatio,ideal_filter_lb,ideal_filter_score);
        
        
        Vy=pos(1)-pos_pre(1);
        Vx=pos(2)-pos_pre(2);
        % search for the scale of object
        [xs,currentScaleFactor,recovered_scale]  = search_scale(sf_num,sf_den,im,pos,base_target_sz,currentScaleFactor,scaleFactors,scale_window,scale_model_sz,min_scale_factor,max_scale_factor,params);
    end
   
    % update the target_sz via currentScaleFactor
    target_sz =round(base_target_sz * currentScaleFactor);
    %save position
     rect_position(loop_frame,:) =[pos([2,1]) - (target_sz([2,1]))/2, target_sz([2,1])];
    
     
     if frame==1 
            % extract training sample image region
             pixels = get_pixels(im,pos,round(sz*currentScaleFactor),sz);
             pixels = uint8(gather(pixels));
             x=get_features(pixels,features,params.t_global);
             xf=fft2(bsxfun(@times,x,cos_window));
             [~,~,w]=init_regwindow(use_sz,reg_sz,params);
             h_ideal= zeros(size(xf));
     else
           % use detection features
            shift_samp_pos = 2*pi * translation_vec ./(currentScaleFactor* sz);
            xf_old=xf;
            xf = 0.038 * shift_sample(xtf, shift_samp_pos, kx', ky') + (1-0.038) * xf_old ; 
     end

        
         
            
     
        %% Update Scale
        if frame==1
            xs = crop_scale_sample(im, pos, base_target_sz, currentScaleFactor * scaleFactors, scale_window, scale_model_sz);
        else
            xs= shift_sample_scale(im, pos, base_target_sz,xs,recovered_scale,currentScaleFactor*scaleFactors,scale_window,scale_model_sz);
        end
        xsf = fft(xs,[],2);
        new_sf_num = bsxfun(@times, ysf, conj(xsf));
        new_sf_den = sum(xsf .* conj(xsf), 1);
        if frame == 1
            sf_den = new_sf_den;
            sf_num = new_sf_num;
        else
            sf_den = (1 - params.learning_rate_scale) * sf_den + params.learning_rate_scale * new_sf_den;
            sf_num = (1 - params.learning_rate_scale) * sf_num + params.learning_rate_scale * new_sf_num;
        end

     time = time + toc();

     %%   visualization
     if params.visualization == 1
        rect_position_vis = [pos([2,1]) - target_sz([2,1])/2, target_sz([2,1])];
        figure(1);
        imshow(im);
        if frame == 1
            hold on;
            rectangle('Position',rect_position_vis, 'EdgeColor','g', 'LineWidth',2);
            text(12, 26, ['# Frame : ' int2str(loop_frame) ' / ' int2str(num_frames)], 'color', [1 0 0], 'BackgroundColor', [1 1 1], 'fontsize', 12);
            hold off;
        else
            hold on;
            rectangle('Position',rect_position_vis, 'EdgeColor','g', 'LineWidth',2);
            text(12, 28, ['# Frame : ' int2str(loop_frame) ' / ' int2str(num_frames)], 'color', [1 0 0], 'BackgroundColor', [1 1 1], 'fontsize', 12);
            text(12, 66, ['FPS : ' num2str(1/(time/loop_frame))], 'color', [1 0 0], 'BackgroundColor', [1 1 1], 'fontsize', 12);
            hold off;
         end
        drawnow
    end
     loop_frame = loop_frame + 1;
end

%   save resutls.
fps = loop_frame / time;
results.type = 'rect';
results.res = rect_position;
results.fps = fps;
end
