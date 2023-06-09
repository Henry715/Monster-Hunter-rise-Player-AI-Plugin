# Monster-Hunter-rise-Player-AI
This is the starting point of building a MHR Player AI(I'm not a expert in this field, and to be honest, I don't know how to train the AI, but I'll try to retrieve all the information needed for training, and I just thought it would be fun), join me if you'd like!
remember to install reframework(download the plugin and follow the installation here: https://www.nexusmods.com/monsterhunterrise/mods/26) and run the game at least once.
# Lua & Python info
The dll for the socket module is compiled with lua 5.4.4(as far as I know, it is also the version that the game uses).
For running the python client, I would recommend you to install anaconda to manage the virtual environment and packages. The python version I'm using is 3.9.16, so I would recommand you to install the same version as well. After the python setup, download the spyder editor from anaconda to load the client.py file. press the green triangular button on the top(well, almost at the top) to run python script.
# Developing state
## 4/18
Well, now the server only sends a message "response" to the client and the client will print it out on the console, it's just a starting point right now, and hopefully I can work on this project till it's finished. And like I said, I'm not an expert in deep reinforcement learning, and this is the first time me creating a MHR game mod. But I know if a person needs to train an AI for a game, the game information and the game stats is crucial, which is what I am doing now, to make the game info and game stats available. So I need experts or maybe just enthusiasts to tell me if the game info is enough for training AI, thanks a lot in advance. If you are also interested, please don't hesitate to join(I am not familiar with any of the github settings, if you need some changes, say role allocation or whatever, please let me know and give me some details of how to achieve that, thank you.)
## 4/22
I have managed to retrieve the quest info from the game,In terms of retrieving damage, I would consider to reuse the code from MHR-Overlay(https://github.com/GreenComfyTea/MHR-Overlay), I tried to retrieve on my own, but it is pretty complicated and too much work for myself, so I'm reusing the code for now(but I'm still considering rewrite the code to reformat the message to the format I'd like). Actually, I'm already using the quest_status from MHR-Overlay to retrieve the quest flow to restrict the server from sending message throughout the whole game.
## 4/23
reading the codes of MHR-Overlay, I can say that I managed to understand most of the code for retrieving the monster info in game, but there are too much for myself to complete, I guess it would be over several months to reorder the code by myself... So I'm definitely sticking with MHR-Overlay for the time being. Ideally, I want it to be in three modules, one for player, one for monster, and another one for the quest.
## 4/24
I'm using the latest version of MHR-Overlay, and if you install MHR-Overlay correctly, then the rest of the steps are just the same. By the way, because I didn't write my own monster_stat module, there is some conflicts with the MHR-Overlay. For example, because I deleted the UI part from a global variable, when using the server, MHR Overlay will miss some of the components, that's the drawback for now. There is also one very strange behaviour of the server, it seems if one accept the quest really quick and starts the game right after acceptinig the quest(which there isn't a lot time gap between two moves), the call method in quest_info breaks.
## 4/25
now player positon is in player stats, you can see that how I extract the position in the client side. And in client side, I only extrated the position of the first monster. This is how the whole message structure look like:
![F4U$T{O09A{N_GT~3_6_P}V](https://user-images.githubusercontent.com/66408806/234291238-a090806c-b80d-4a67-97e1-8cbd144b9ba5.png)
and this is how the player_stats looks like:
![GVX U0$AIZK5OPI18}OU}(H](https://user-images.githubusercontent.com/66408806/234291572-d47187eb-1b3f-4fd1-9647-1f6e417ab1c3.png)
To control the player, you can use a package called "pydirectinput"(https://github.com/learncodebygaming/pydirectinput) together with the package called "pyautogui", pydirectinput substitutes some of the functions in pyautogui that doesn't work in a modern game(like pyautogui.keyDown()). I have tested it with some of the keys in MHR, well, at least "wasd" keys works. So theoratically, I think now we are able to train the hunter to walk to one of the target monster with these necessary infos to begin with. 

# Game stats to send for now
## 4/18
now the server sends no useful information, but there are some that is already on my mind, for example, the position, HP of the player and monster, damages received, damages caused by the player and the monster, quest stats(# of carts, fail or success?), quest time, maybe even buff stats. For the next update, I will try to fetch all relevent player and monster info and send it to the client.
## 4/22
now the Server sends the quest info (for example, the targeted monster to hunt, the targeted monster ID, how many carts left, how many lives was given by the quest. Quest time elapsed in seconds and minutes, the time limit for the quest in minutes. How many targets hunted, whether the mission has been completed) to the client only after the hunt starts. like the screenshot below:
![quest_info](https://user-images.githubusercontent.com/66408806/233784558-668e0914-aac6-4413-a345-ae1d79be571c.png)
Put the stats folder inside the auto run folder generated by reframework. And remember to download the MHR-Overlay as well, as I have used the quest_status module from there. I will not upload MHR-Overlay code here for now, but I will upload the version with my own modifications afterwards(basically what I will do is to reformat the message a bit and delete all the contents that are related to the UI).
## 4/24
detailed monster info and stats can be sent to the client, the player is very similar with sending the monster_stats, if you cannot wait, just try it yourself. And I think when developing a game agent, you probably won't training the agent with other human players, all the information about the player is inside (player.myself) that lua table(I assume you know what I meant) and be aware that the damage in player.myself is the total damage the player dealt, not the damage dealt at this moment. And some parts of the player I think is important are missing, like stamina value, vital value, and the sharpness of the weapon, and I would like to get the Item list, too. So I'll try to retrieve these info in the next few days.(by the way, I haven't access the value of the monster and store it in other place. If you'd like to know, lua can access the vector using "." operation, so the monster position is [position.x, position.y, position.z], but you can only do this on the server side, as the vector sent over the network becomes null). And you might ask why I need to delete the UI infos before sendinig it to the client, because there is some special characters inside of it and the json package in python cannot load it.

# File location
After you installed reframework plugin (run the game once and you'll have the auto run folder),

put the server.lua into autorun folder and change the file path to something similar in the file,but I guess most likely the only thing you need to change is the drver name in the path, I put the steam library inside my D drive. And make sure that the path doesn't have any special characters, which might cause issue:![1681821866882](https://user-images.githubusercontent.com/66408806/232782011-d4037919-3eb0-4b0e-ad47-847b63baefe0.png)
And then put the socket folder into the game's root folder:![1681821883470](https://user-images.githubusercontent.com/66408806/232782156-2af22a25-0c5c-4ac6-9240-41b62e2c208a.png)

In terms of Python client, you can put it anywhere you'd like, as long as you can run the client, that would be fine.
And start the game again, after a while you might see the game freezes, don't worry, because that is the server waiting for a connection from the client. After you start the client, the game will run the same as expected.
# About me
I'm just a computer science student that just graduated from university and loves Monster Hunter series.

