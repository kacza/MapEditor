import { GameObject } from '@/script/types/GameObject';
import * as THREE from 'three';
import { signals } from '@/script/modules/Signals';
import { LinearTransform } from '@/script/types/primitives/LinearTransform';
import { GameObjectTransferData } from '@/script/types/GameObjectTransferData';
import { SetTransformCommand } from '@/script/commands/SetTransformCommand';
import BulkCommand from '@/script/commands/BulkCommand';
import EnableGameObjectCommand from '@/script/commands/EnableGameObjectCommand';
import DisableGameObjectCommand from '@/script/commands/DisableGameObjectCommand';

export class SelectionGroup extends THREE.Object3D {
	public selectedGameObjects: GameObject[] = [];
	public transform: LinearTransform = new LinearTransform();

	constructor() {
		super();
		this.type = 'SelectionGroup';
		this.name = 'Selection Group';
		this.visible = true;
		// signals.objectChanged.connect(this.onObjectChanged.bind(this));
	}

	public onClientOnlyMove() {
		// Calculate the matrices of the selected objects.
		this.updateSelectedGameObjects();

		editor.threeManager.nextFrame(() => {
			signals.selectionGroupChanged.emit(this, 'transform', this.transform);
		});
	}

	public onClientOnlyMoveEnd() {
		this.updateMatrixWorld(true);
		const commands = [];
		for (const gameObject of this.selectedGameObjects) {
			if (!gameObject.hasMoved()) {
				return; // No position change
			}
			const transform = new LinearTransform().setFromMatrix(gameObject.matrixWorld);
			const command = new SetTransformCommand(
				new GameObjectTransferData({
					guid: gameObject.guid,
					transform: gameObject.transform
				}),
				transform
			);
			commands.push(command);
		}

		if (commands.length === 0) {
			return;
		}
		if (commands.length === 1) {
			editor.execute(commands[0]);
		} else {
			editor.execute(new BulkCommand(commands));
		}
	}

	/**
	 * Moves all selected objects relative to the selection group. As SelectionGroup doesn't add the selected objects as
	 * children, we have to manually calculate their new matrices. First we calc the SelectionGroup's transformation
	 * matrix with the new and old SelectionGroup's matrices. Then we calc each GameObject transform relative to SelectionGroup
	 * so we can now apply the transformation matrix to get their new matrices.
	 */
	public updateSelectedGameObjects(oldMatrix = this.transform.toMatrix(), newMatrix = this.matrixWorld) {
		this.updateMatrixWorld(true);
		const selectionGroupWorld = oldMatrix;
		const selectionGroupWorldNew = newMatrix;

		const selectionOldMatrixInverse = new THREE.Matrix4().copy(selectionGroupWorld).invert();
		const transformMatrix = new THREE.Matrix4().multiplyMatrices(selectionGroupWorldNew, selectionOldMatrixInverse);
		const childLocal = new THREE.Matrix4();
		const childLocalNew = new THREE.Matrix4();
		const childWorldNew = new THREE.Matrix4();

		for (const go of this.selectedGameObjects) {
			go.updateMatrixWorld(true);
			childLocal.multiplyMatrices(go.matrixWorld, selectionOldMatrixInverse); // calculates go's matrix relative to selection group
			childLocalNew.multiplyMatrices(transformMatrix, childLocal); // calculates go's new matrix with transformation matrix
			childWorldNew.multiplyMatrices(childLocalNew, selectionGroupWorld); // local to world transform
			go.setWorldMatrix(childWorldNew, false);
			go.updateMatrixWorld(true);
			signals.objectChanged.emit(go, 'transform', go.transform);
		}
		// Save new matrix.
		this.transform = new LinearTransform().setFromMatrix(selectionGroupWorldNew);
	}

	public setMatrix(matrix: THREE.Matrix4) {
		this.transform = new LinearTransform().setFromMatrix(matrix);
		matrix.decompose(this.position, this.quaternion, this.scale);
		this.updateMatrix();
		editor.threeManager.nextFrame(() => signals.selectionGroupChanged.emit(this, 'transform', this.transform));
	}

	public setPosition(x: number, y: number, z: number) {
		this.position.set(x, y, z);
		this.updateSelectedGameObjects();
		editor.threeManager.setPendingRender();
		// editor.threeManager.nextFrame(() => signals.selectionGroupChanged.emit(this, 'transform', this.transform));
	}

	public RefreshTransform(): void {
		if (this.selectedGameObjects.length !== 0) {
			this.setMatrix(this.selectedGameObjects[0].matrixWorld);
		}
	}

	public select(gameObject: GameObject, multiSelection: boolean, scrollTo: boolean, moveGizmo: boolean) {
		if (!gameObject) {
			return;
		}

		if (!multiSelection) {
			this.deselectAll();
		}

		// Disabled multiselection deselection for now
		if (multiSelection) {
			// If object is already selected and its multiSelection deselect it.
			if (gameObject.selected) {
				// Edge case:
				// Can't deselect a child of a GameObject that is currently selected.
				if (!this.isSelected(gameObject)) {
					// TODO: Maybe add a ui console message?
					return;
				}

				this.deselect(gameObject);
				return;
			}
			// Edge case:
			// Selecting a parent of a selected object(s) should deselect that/those object(s) first.
			if (this.selectedGameObjects.length > 0 && gameObject.children.length > 0) {
				// Find out if each selected objects are descendants of the new object.
				for (const selectedGo of this.selectedGameObjects) {
					if ((selectedGo as GameObject).descendantOf(gameObject)) {
						this.deselect(selectedGo);
					}
				}
			}
		}

		// If first object move group to its position
		if (this.selectedGameObjects.length === 0 || moveGizmo) {
			this.setMatrix(gameObject.matrixWorld);
		}
		this.selectedGameObjects.push(gameObject);
		gameObject.onSelect();
		this.makeParentsVisible();
		signals.selectedGameObject.emit(gameObject.guid, multiSelection, scrollTo);
	}

	public deselectAll() {
		for (const go of this.selectedGameObjects) {
			go.onDeselect();
			signals.deselectedGameObject.emit(go.guid);
		}

		this.makeParentsInvisible();
		this.selectedGameObjects = [];
	}

	// Find game object, deselect it and remove it from array.
	public deselect(gameObject: GameObject) {
		const index = this.selectedGameObjects.findIndex((go) => go.guid === gameObject.guid);
		if (index === -1) return;
		signals.deselectedGameObject.emit(gameObject.guid);
		gameObject.onDeselect();
		this.selectedGameObjects.splice(index, 1);
		if (!window.vext.executing) {
			// this.makeParentsInvisible();
			// this.makeParentsVisible();
		}
	}

	public makeParentsInvisible() {
		for (const go of this.selectedGameObjects) {
			go.makeParentsInvisible();
		}
	}

	public makeParentsVisible() {
		for (const go of this.selectedGameObjects) {
			go.makeParentsVisible();
		}
	}

	public selectParent() {
		if (this.selectedGameObjects.length !== 1) {
			return;
		}

		const go = this.selectedGameObjects[0];
		if (go.parent != null && go.parent.constructor === GameObject) {
			this.select(go.parent, false, true, true);
		}
	}

	public isSelected(go: GameObject) {
		return this.selectedGameObjects.includes(go);
	}

	public enable() {
		const commands = [];

		for (const gameObject of this.selectedGameObjects) {
			const command = new EnableGameObjectCommand(
				new GameObjectTransferData({
					guid: gameObject.guid
				})
			);
			commands.push(command);
		}

		if (commands.length === 0) {
			return;
		}

		if (commands.length === 1) {
			editor.execute(commands[0]);
		} else {
			editor.execute(new BulkCommand(commands));
		}
	}

	public disable() {
		const commands = [];

		for (const gameObject of this.selectedGameObjects) {
			const command = new DisableGameObjectCommand(
				new GameObjectTransferData({
					guid: gameObject.guid
				})
			);
			commands.push(command);
		}

		if (commands.length === 0) {
			return;
		}

		if (commands.length === 1) {
			editor.execute(commands[0]);
		} else {
			editor.execute(new BulkCommand(commands));
		}
	}
}
