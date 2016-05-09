//
//  FriendsTableViewController.swift
//  VkPlaylist
//
//  Created by Илья Халяпин on 09.05.16.
//  Copyright © 2016 Ilya Khalyapin. All rights reserved.
//

import UIKit

class FriendsTableViewController: UITableViewController {

    private var imageCache: NSCache!
    private var names: [String: [Friend]]!
    private var nameSectionTitles: [String]!
    
    private var filteredFriends: [Friend]! // Массив для результатов поиска по уже загруженным личным аудиозаписям
    
    var searchController: UISearchController!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if VKAPIManager.isAuthorized {
            imageCache = NSCache()
            names = [:]
            nameSectionTitles = []
            filteredFriends = []
            
            getFriends()
        }
        
        
        // Настройка поисковой панели
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        
        searchController.dimsBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.searchBarStyle = .Prominent
        searchController.searchBar.placeholder = "Поиск"
        definesPresentationContext = true
        
        if VKAPIManager.isAuthorized {
            searchEnable(true)
        }
        
        
        // Регистрация ячеек
        var cellNib = UINib(nibName: TableViewCellIdentifiers.noAuthorizedCell, bundle: nil) // Ячейка "Необходимо авторизоваться"
        tableView.registerNib(cellNib, forCellReuseIdentifier: TableViewCellIdentifiers.noAuthorizedCell)
        
        cellNib = UINib(nibName: TableViewCellIdentifiers.networkErrorCell, bundle: nil) // Ячейка "Ошибка при подключении к интернету"
        tableView.registerNib(cellNib, forCellReuseIdentifier: TableViewCellIdentifiers.networkErrorCell)
        
        cellNib = UINib(nibName: TableViewCellIdentifiers.nothingFoundCell, bundle: nil) // Ячейка "Ничего не найдено"
        tableView.registerNib(cellNib, forCellReuseIdentifier: TableViewCellIdentifiers.nothingFoundCell)
        
        cellNib = UINib(nibName: TableViewCellIdentifiers.loadingCell, bundle: nil) // Ячейка "Загрузка"
        tableView.registerNib(cellNib, forCellReuseIdentifier: TableViewCellIdentifiers.loadingCell)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        imageCache.removeAllObjects()
    }
    
    // Заново отрисовать таблицу
    func reloadTableView() {
        dispatch_async(dispatch_get_main_queue()) {
            self.tableView.reloadData()
        }
    }
    
    
    // MARK: Работа с клавиатурой
    
    lazy var tapRecognizer: UITapGestureRecognizer = {
        var recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        return recognizer
    }()
    
    // Спрятать клавиатуру у поисковой строки
    func dismissKeyboard() {
        searchController.searchBar.resignFirstResponder()
        
        if searchController.active && searchController.searchBar.text!.isEmpty {
            searchController.active = false
        }
    }
    
    
    // MARK: Выполнение запроса на получение списка друзей
    
    func getFriends() {
        RequestManager.sharedInstance.getFriends.performRequest() { success in
            
            // Распределяем по секциям
            if RequestManager.sharedInstance.getFriends.state == .Results {
                for friend in DataManager.sharedInstance.friends.array {
                    
                    // Устанавливаем по какому значению будем сортировать
                    let name: String
                    if let last_name = friend.last_name {
                        name = last_name
                    } else if let first_name = friend.first_name {
                        name = first_name
                    } else {
                        name = "#"
                    }
                    
                    var firstCharacter = String(name.characters.first!)
                    
                    let characterSet = NSCharacterSet(charactersInString: "абвгдеёжзийклмнопрстуфхцчшщъыьэюя" + "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ" + "abcdefghijklmnopqrstuvwxyz" + "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                    if (NSString(string: firstCharacter).rangeOfCharacterFromSet(characterSet.invertedSet).location != NSNotFound){
                        firstCharacter = "#"
                    }
                    
                    if self.names[String(firstCharacter)] == nil {
                        self.names[String(firstCharacter)] = []
                    }
                    
                    self.names[String(firstCharacter)]!.append(friend)
                }
                
                self.nameSectionTitles = self.names.keys.sort { (left: String, right: String) -> Bool in
                    return left.localizedStandardCompare(right) == .OrderedAscending // Сортировка по возрастанию
                }
                
                if self.nameSectionTitles.first == "#" {
                    self.nameSectionTitles.removeFirst()
                    self.nameSectionTitles.append("#")
                }
            }
            
            self.reloadTableView()
            
            
            if !success {
                switch RequestManager.sharedInstance.getFriends.error {
                case .NetworkError:
                    break
                case .UnknownError:
                    let alertController = UIAlertController(title: "Ошибка", message: "Произошла какая-то ошибка, попробуйте еще раз...", preferredStyle: .Alert)
                    
                    let okAction = UIAlertAction(title: "ОК", style: .Default, handler: nil)
                    alertController.addAction(okAction)
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        self.presentViewController(alertController, animated: false, completion: nil)
                    }
                default:
                    break
                }
            }
        }
    }
    
    
    // MARK: Поиск
    
    func searchEnable(enable: Bool) {
        if enable {
            searchController.searchBar.alpha = 1
            tableView.tableHeaderView = searchController.searchBar
            tableView.contentOffset = CGPointMake(0, CGRectGetHeight(searchController.searchBar.frame)) // Прячем строку поиска
        } else {
            searchController.searchBar.alpha = 0
            searchController.active = false
            tableView.tableHeaderView = nil
            tableView.contentOffset = CGPointZero
        }
    }
    
    func filterContentForSearchText(searchText: String) {
        filteredFriends = DataManager.sharedInstance.friends.array.filter { friend in
            return friend.first_name!.lowercaseString.containsString(searchText.lowercaseString) || friend.last_name!.lowercaseString.containsString(searchText.lowercaseString)
        }
    }

}

// MARK: UITableViewDataSource

private typealias FriendsTableViewControllerDataSource = FriendsTableViewController
extension FriendsTableViewControllerDataSource {
    
    // Получение количество секций
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if VKAPIManager.isAuthorized {
            switch RequestManager.sharedInstance.getFriends.state {
            case .Results:
                if searchController.active && searchController.searchBar.text != "" {
                    return 1
                }
                
                return nameSectionTitles.count
            default:
                return 1
            }
        }
        
        return 1
    }
    
    // Получение заголовков секций
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if VKAPIManager.isAuthorized {
            switch RequestManager.sharedInstance.getFriends.state {
            case .Results:
                if searchController.active && searchController.searchBar.text != "" {
                    return nil
                }
                
                return nameSectionTitles[section]
            default:
                return nil
            }
        }
        
        return nil
    }
    
    // Получение количества строк таблицы в указанной секции
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if VKAPIManager.isAuthorized {
            switch RequestManager.sharedInstance.getFriends.state {
            case .NotSearchedYet where RequestManager.sharedInstance.getFriends.error == .NetworkError:
                return 1 // Ячейка с сообщением об отсутствии интернет соединения
            case .Loading:
                return 1 // Ячейка с индикатором загрузки
            case .NoResults:
                return 1 // Ячейки с сообщением об отсутствии друзей
            case .Results:
                if searchController.active && searchController.searchBar.text != "" {
                    return filteredFriends.count == 0 ? 1 : filteredFriends.count // Если массив пустой - ячейка с сообщением об отсутствии результатов поиска, иначе - количество найденных друзей
                }
                
                let sectionTitle = nameSectionTitles[section]
                let sectionNames = names[sectionTitle]
                
                return sectionNames!.count
            default:
                return 0
            }
        }
        
        return 1 // Ячейка с сообщением о необходимости авторизоваться
    }
    
    // Получение ячейки для строки таблицы
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if VKAPIManager.isAuthorized {
            switch RequestManager.sharedInstance.getFriends.state {
            case .NotSearchedYet where RequestManager.sharedInstance.getFriends.error == .NetworkError:
                let cell = tableView.dequeueReusableCellWithIdentifier(TableViewCellIdentifiers.networkErrorCell, forIndexPath: indexPath) as! NetworkErrorCell
                return cell
            case .NoResults:
                let cell = tableView.dequeueReusableCellWithIdentifier(TableViewCellIdentifiers.nothingFoundCell, forIndexPath: indexPath) as! NothingFoundCell
                
                cell.messageLabel.text = "Список друзей пуст"
                
                return cell
            case .Loading:
                let cell = tableView.dequeueReusableCellWithIdentifier(TableViewCellIdentifiers.loadingCell, forIndexPath: indexPath) as! LoadingCell
                
                cell.activityIndicator.startAnimating()
                
                return cell
            case .Results:
                if searchController.active && searchController.searchBar.text != "" && filteredFriends.count == 0 {
                    let nothingFoundCell = tableView.dequeueReusableCellWithIdentifier(TableViewCellIdentifiers.nothingFoundCell, forIndexPath: indexPath) as! NothingFoundCell
                    
                    nothingFoundCell.messageLabel.text = "Измените поисковый запрос"
                    
                    return nothingFoundCell
                }
                
                
                let cell = tableView.dequeueReusableCellWithIdentifier(TableViewCellIdentifiers.friendCell, forIndexPath: indexPath) as! FriendCell
                let sectionTitle = nameSectionTitles[indexPath.section]
                let sectionNames = names[sectionTitle]
                var friend: Friend
                
                if searchController.active && searchController.searchBar.text != "" {
                    friend = filteredFriends[indexPath.row]
                } else {
                    friend = sectionNames![indexPath.row]
                }
                
                cell.configureForFriend(friend, withImageCacheStorage: imageCache)
                
                return cell
            default:
                return UITableViewCell()
            }
        }
        
        let cell = tableView.dequeueReusableCellWithIdentifier(TableViewCellIdentifiers.noAuthorizedCell, forIndexPath: indexPath) as! NoAuthorizedCell
        
        cell.messageLabel.text = "Для отображения списка личных аудиозаписей необходимо авторизоваться"
        
        return cell
    }
    
    // Получение массива индексов секций таблицы
    override func sectionIndexTitlesForTableView(tableView: UITableView) -> [String]? {
        if VKAPIManager.isAuthorized {
            switch RequestManager.sharedInstance.getFriends.state {
            case .Results:
                if searchController.active && searchController.searchBar.text != "" {
                    return nil
                }
                
                return nameSectionTitles
            default:
                return nil
            }
        }
        
        return nil
    }
    
}


// MARK: UITableViewDelegate

private typealias FriendsTableViewControllerDelegate = FriendsTableViewController
extension FriendsTableViewControllerDelegate {
    
    
    // Высота каждой строки
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 62
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
}


// MARK: UISearchBarDelegate

extension FriendsTableViewController: UISearchBarDelegate {
    
    // Вызывается когда пользователь начал редактирование поискового текста
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        view.addGestureRecognizer(tapRecognizer)
    }
    
    // Вызывается когда пользователь закончил редактирование поискового текста
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
        view.removeGestureRecognizer(tapRecognizer)
    }
    
}


// MARK: UISearchResultsUpdating

extension FriendsTableViewController: UISearchResultsUpdating {
    
    // Вызывается когда поле поиска получает фокус или когда значение поискового запроса изменяется
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text!)
        reloadTableView()
    }
    
}