function [pos,translation_vec,ideal_filter_lb,ideal_filter_score,h_ideal] = run_detection(params,im,center,xtf,currentScaleFactor,g_f,use_sz,ky,kx,newton_iterations,featureRatio,ideal_filter_lb,ideal_filter_score)

        responsef_ori=bsxfun(@times, conj(g_f), xtf);
        response_ori=ifft2(responsef_ori, 'symmetric');
        
        responsef=sum(responsef_ori,3);
        
        % if we undersampled features, we want tso interpolate the
        % response so it has the same size as the image patch
        responsef_padded = resizeDFT2(responsef, use_sz);
        
        % response in the spatial domain
        response = ifft2(responsef_padded, 'symmetric');
        
        
        % find maximum peak
        [disp_row, disp_col] = resp_newton(response, responsef_padded,newton_iterations, ky, kx, use_sz);
        % calculate translation
        translation_vec = round([disp_row, disp_col] * featureRatio * currentScaleFactor);
        %update position
        pos = center + translation_vec;
        
        %evaluate the quality of each channel of the response
        dim=size(response_ori,3);
        [x,y]=find(response==max(max(response())));
        x=x(1);
        y=y(1);
        for channel = 1: dim
            response_dim = response_ori(:,:,channel);
            a=(var(response_dim(:)));
            if a==0
                channel_quality=1;
            else
                channel_quality= ((response_dim(x,y)-min(min(response_dim)))^2)/a ;
            end
            c_i=ideal_filter_score(channel,:);
            [nvalue,nindex]=min(c_i);
            if channel_quality>nvalue
                ideal_filter_score(channel,nindex)=channel_quality;
                ideal_filter_lb{channel,nindex}=g_f(:,:,channel);
            end
        end
        ideal_filter_score = ideal_filter_score * exp((-1)*params.decey);
        [xvalue,xindex]=max(ideal_filter_score,[],2);
        h_ideal=zeros(size(xtf));
        for i=1:42
            h_ideal(:,:,i)=ideal_filter_lb{i,xindex};
        end

        if pos(1)>size(im,1)-use_sz(1)/2
            pos(1)=size(im,1)-use_sz(1)/2;
        end
        
        if pos(1)<1+use_sz(1)/2
            pos(1)=1+use_sz(1)/2;
        end
        
        if pos(2)>size(im,2)-use_sz(1)/2
            pos(2)=size(im,2)-use_sz(1)/2;
        end
        
        if pos(2)<1+use_sz(1)/2
            pos(2)=1+use_sz(1)/2;
        end
        
        
        
        
        
end

