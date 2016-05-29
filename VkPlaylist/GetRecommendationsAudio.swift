//
//  GetRecommendationsAudio.swift
//  VkPlaylist
//
//  Created by Илья Халяпин on 11.05.16.
//  Copyright © 2016 Ilya Khalyapin. All rights reserved.
//

import UIKit

/// Получение списка рекомендуемых аудиозаписей

class GetRecommendationsAudio: RequestManagerObject {
    
    override func performRequest(parameters: [Argument : AnyObject], withCompletionHandler completion: (Bool) -> Void) {
        super.performRequest(parameters, withCompletionHandler: completion)
        
        // Отмена выполнения предыдущего запроса и удаление загруженной информации
        cancel()
        DataManager.sharedInstance.recommendationsMusic.clear()
        
        // Если нет подключения к интернету
        if !Reachability.isConnectedToNetwork() {
            state = .NotSearchedYet
            error = .NetworkError
            
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            
            completion(false)
            
            return
        }
        
        
        // Слушатель для уведомления об успешном завершении получения аудиозаписей
        NSNotificationCenter.defaultCenter().addObserverForName(VKAPIManagerDidGetRecommendationsAudioNotification, object: nil, queue: NSOperationQueue.mainQueue()) { notification in
            self.removeActivState() // Удаление состояние выполнения запроса
            
            // Сохранение данных
            let result = notification.userInfo!["Audio"] as! [Track]
            
            DataManager.sharedInstance.recommendationsMusic.update(result)
            self.state = DataManager.sharedInstance.recommendationsMusic.array.count == 0 ? .NoResults : .Results
            self.error = .None
            
            completion(true)
        }
        
        // Слушатель для получения уведомления об ошибке при подключении к интернету
        NSNotificationCenter.defaultCenter().addObserverForName(VKAPIManagerGetRecommendationsAudioNetworkErrorNotification, object: nil, queue: NSOperationQueue.mainQueue()) { _ in
            self.removeActivState() // Удаление состояние выполнения запроса
            
            // Сохранение данных
            DataManager.sharedInstance.recommendationsMusic.clear()
            self.state = .NotSearchedYet
            self.error = .NetworkError
            
            completion(false)
        }
        
        // Слушатель для уведомления о других ошибках
        NSNotificationCenter.defaultCenter().addObserverForName(VKAPIManagerGetRecommendationsAudioErrorNotification, object: nil, queue: NSOperationQueue.mainQueue()) { _ in
            self.removeActivState() // Удаление состояние выполнения запроса
            
            // Сохранение данных
            DataManager.sharedInstance.recommendationsMusic.clear()
            self.state = .NotSearchedYet
            self.error = .UnknownError
            
            completion(false)
        }
        
        
        let request = VKAPIManager.audioGetRecommendations()
        
        state = .Loading
        error = .None
        
        RequestManager.sharedInstance.activeRequests[key] = request
    }
    
}