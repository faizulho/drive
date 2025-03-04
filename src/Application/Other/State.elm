module Other.State exposing (..)

import Authentication.Essentials as Authentication
import Browser
import Browser.Navigation as Navigation
import Common
import Common.State as Common
import Drive.State as Drive
import FileSystem
import Keyboard
import Maybe.Extra as Maybe
import Ports
import Radix exposing (..)
import Return exposing (return)
import Return.Extra as Return
import Routing exposing (Route(..))
import Time
import Url exposing (Url)



-- 🛠


appUpdateAvailable : Manager
appUpdateAvailable model =
    Return.singleton { model | appUpdate = Installing }


appUpdateFinished : Manager
appUpdateFinished model =
    Return.singleton { model | appUpdate = Installed }


gotInitialisationError : String -> Manager
gotInitialisationError err model =
    Return.singleton
        { model | initialised = Err err }


hideWelcomeMessage : Manager
hideWelcomeMessage model =
    model.authenticated
        |> Maybe.map (\a -> { a | newUser = False })
        |> (\a -> { model | authenticated = a })
        |> Return.singleton


initialise : Maybe Authentication.Essentials -> Manager
initialise maybeEssentials model =
    let
        route =
            Routing.routeFromUrl maybeEssentials model.url
    in
    Return.singleton
        { model
            | authenticated = maybeEssentials
            , fileSystemStatus =
                if Maybe.isJust maybeEssentials then
                    FileSystem.Loading

                else
                    FileSystem.NotNeeded
            , initialised = Ok True
            , route = route
            , showLoadingOverlay = False
        }


keyboardInteraction : Keyboard.Msg -> Manager
keyboardInteraction msg unmodified =
    (if unmodified.isFocused then
        []

     else
        Keyboard.update msg unmodified.pressedKeys
    )
        |> (\p ->
                { unmodified | pressedKeys = p }
           )
        |> (\m ->
                case m.pressedKeys of
                    [ Keyboard.ArrowDown ] ->
                        Drive.selectNextItem m

                    [ Keyboard.ArrowUp ] ->
                        Drive.selectPreviousItem m

                    [ Keyboard.Character "T" ] ->
                        Drive.toggleExpandedSidebar m

                    [ Keyboard.Character "U" ] ->
                        Drive.goUpOneLevel m

                    [ Keyboard.Enter ] ->
                        Drive.digDeeperUsingSelection m

                    [ Keyboard.Escape ] ->
                        Drive.closeSidebar m

                    _ ->
                        Return.singleton m
           )


lostWindowFocus : Manager
lostWindowFocus model =
    Return.singleton { model | pressedKeys = [] }


ready : Manager
ready model =
    let
        route =
            model.route

        maybeTreeRoot =
            Routing.treeRoot route

        fileSystemStatus =
            if Maybe.isJust maybeTreeRoot then
                FileSystem.InitialListing

            else
                FileSystem.NotNeeded

        needsRedirect =
            (Routing.isAuthenticatedTree model.authenticated route == False)
                && (List.head (Routing.treePathSegments route) == Just "public")
    in
    return
        -----------------------------------------
        -- Model
        -----------------------------------------
        { model | fileSystemStatus = fileSystemStatus }
        -----------------------------------------
        -- Command
        -----------------------------------------
        (if needsRedirect then
            route
                |> Routing.treePathSegments
                |> List.drop 1
                |> Routing.replaceTreePathSegments route
                |> Routing.adjustUrl model.url
                |> Url.toString
                |> Navigation.pushUrl model.navKey

         else if Routing.isAuthenticatedTree model.authenticated route then
            -- List entire file system for the authenticated user
            Ports.fsListDirectory
                { pathSegments = Routing.treePathSegments route }

         else if Maybe.isJust maybeTreeRoot then
            -- List a public filesystem
            Ports.fsListPublicDirectory
                { pathSegments =
                    Routing.treePathSegments route
                , root =
                    Common.filesDomainFromTreeRoot
                        { usersDomain = model.usersDomain }
                        maybeTreeRoot
                }

         else
            Cmd.none
        )


screenSizeChanged : Int -> Int -> Manager
screenSizeChanged width height model =
    let
        viewportSize =
            { height = height
            , width = width
            }
    in
    Return.singleton
        { model
            | contextMenu = Nothing
            , viewportSize = viewportSize
        }


setCurrentTime : Time.Posix -> Manager
setCurrentTime time model =
    Return.singleton { model | currentTime = time }



-- FOCUS


{-| Some element has lost focus.
-}
blurred : Manager
blurred model =
    Return.singleton { model | isFocused = False }


{-| Some element has received focus.
-}
focused : Manager
focused model =
    Return.singleton { model | isFocused = True }



-- URL


linkClicked : Browser.UrlRequest -> Manager
linkClicked urlRequest model =
    case urlRequest of
        Browser.Internal url ->
            return model (Navigation.pushUrl model.navKey <| Url.toString url)

        Browser.External href ->
            return model (Navigation.load href)


redirectToLobby : Manager
redirectToLobby =
    Return.communicate (Ports.redirectToLobby ())


toggleLoadingOverlay : { on : Bool } -> Manager
toggleLoadingOverlay { on } model =
    Return.singleton { model | showLoadingOverlay = on }


{-| This function is responsible for changing the application state based on the URL.
-}
urlChanged : Url -> Manager
urlChanged url old =
    let
        stillLoading =
            old.fileSystemStatus == FileSystem.Loading

        route =
            Routing.routeFromUrl old.authenticated url

        isTreeRoute =
            case route of
                Tree _ _ ->
                    True

                _ ->
                    False

        ( oldRoot, newRoot ) =
            ( Routing.treeRoot old.route
            , Routing.treeRoot route
            )

        isDifferentRoot =
            Maybe.isJust oldRoot && Maybe.isJust newRoot && oldRoot /= newRoot
    in
    { old
        | fileSystemStatus =
            if stillLoading || not isTreeRoute then
                old.fileSystemStatus

            else if isDifferentRoot then
                FileSystem.InitialListing

            else
                FileSystem.AdditionalListing

        --
        , pressedKeys = []
        , route = route
        , url = url
    }
        |> Drive.clearDirectoryListSelection
        |> (\new ->
                if stillLoading || not isTreeRoute then
                    Return.singleton new

                else if isTreeRoute && old.route /= new.route then
                    if Routing.isAuthenticatedTree new.authenticated new.route then
                        { pathSegments = Routing.treePathSegments new.route }
                            |> Ports.fsListDirectory
                            |> return new

                    else
                        { pathSegments =
                            Routing.treePathSegments new.route
                        , root =
                            Common.filesDomainFromTreeRoot
                                { usersDomain = new.usersDomain }
                                newRoot
                        }
                            |> Ports.fsListPublicDirectory
                            |> return new

                else
                    Return.singleton new
           )
