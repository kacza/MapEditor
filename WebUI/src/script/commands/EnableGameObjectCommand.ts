import { GameObjectTransferData } from '@/script/types/GameObjectTransferData';
import { VextCommand } from '@/script/types/VextCommand';
import Command from '@/script/libs/three/Command';

export default class EnableGameObjectCommand extends Command {
	constructor(public gameObjectTransferData: GameObjectTransferData) {
		super('EnableGameObjectCommand');
		this.name = 'Enable GameObject';
	}

	public execute() {
		const gameObjectTransferData = new GameObjectTransferData({
			guid: this.gameObjectTransferData.guid
		});
		window.vext.SendCommand(new VextCommand(this.type, gameObjectTransferData));
	}

	public undo() {
		const gameObjectTransferData = new GameObjectTransferData({
			guid: this.gameObjectTransferData.guid
		});
		window.vext.SendCommand(new VextCommand('DisableGameObjectCommand', gameObjectTransferData));
	}
}
